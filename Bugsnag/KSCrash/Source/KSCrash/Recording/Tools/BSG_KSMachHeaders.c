//
//  BSG_KSMachHeaders.c
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#include "BSG_KSMachHeaders.h"

#include "BSG_KSLogger.h"
#include "BSG_KSMach.h"
#include "BSG_KSImageMemory.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <os/trace.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

// Copied from https://github.com/apple/swift/blob/swift-5.0-RELEASE/include/swift/Runtime/Debug.h#L28-L40

#define CRASHREPORTER_ANNOTATIONS_VERSION 7
#define CRASHREPORTER_ANNOTATIONS_SECTION "__crash_info"

// TODO: Update after PLAT-15173
struct crashreporter_annotations_t {
    uint64_t version;          // unsigned long
    uint64_t message;          // char *
    uint64_t signature_string; // char *
    uint64_t backtrace;        // char *
    uint64_t message2;         // char *
    uint64_t thread;           // uint64_t
    uint64_t dialog_mode;      // unsigned int
    uint64_t abort_cause;      // unsigned int
};

typedef struct BSG_Mach_Image_Node {
    BSG_Mach_Header_Info info;
    struct BSG_Mach_Image_Node *next;
} BSG_Mach_Image_Node;

static const struct dyld_all_image_infos *g_all_image_infos;
static BSG_Mach_Image_Node *g_cached_images_head;
static BSG_Mach_Image_Node *g_cached_images_tail;
static BSG_Mach_Image_Node *g_main_image;
static BSG_Mach_Image_Node *g_self_image;
static BSG_Mach_Image_Node *g_dyld_image;
static _Atomic(uint32_t) g_cached_image_count;
enum { BSGImagesUninitialized, BSGImagesInitializing, BSGImagesReady };
static _Atomic(int) g_initialization_state;

// Only dyld shared-cache images are retained here: unlike dlopen images, they
// cannot be unmapped. A busy cache is bypassed, never waited on by a crash handler.
#define BSG_SHARED_IMAGE_CACHE_CAPACITY 64
static BSG_Mach_Header_Info g_shared_images[BSG_SHARED_IMAGE_CACHE_CAPACITY];
static uint32_t g_shared_image_count;
static atomic_flag g_shared_images_busy = ATOMIC_FLAG_INIT;
static void (*g_initialization_hook)(void); // Test-only, set before initialization.
static void (*g_get_images_hook)(int attempt, int stage); // Test-only, see get_images().



static const char *get_path(const struct mach_header *header);
static bool populate_image_info(const struct mach_header *header, intptr_t slide,
                                const char *name,
                                BSG_Mach_Header_Info *info);
static bool image_contains_address(const BSG_Mach_Header_Info *image,
                                   uintptr_t address);
static BSG_Mach_Image_Node *find_cached_image_at_address(uintptr_t address);
static BSG_Mach_Image_Node *find_cached_image_named(const char *imageName,
                                                    bool exactMatch);
static bool copy_cached_image(const BSG_Mach_Image_Node *node,
                              BSG_Mach_Header_Info *image);
static bool cache_image(const BSG_Mach_Header_Info *image,
                        BSG_Mach_Image_Node **slot);
static void clear_cached_images(void);
static bool cache_image_for_header(const struct mach_header *header,
                                   const char *name,
                                   BSG_Mach_Image_Node **slot);

static void register_dyld_images(void);

void bsg_mach_headers_copy_image(BSG_Mach_Header_Info *destination,
                                const BSG_Mach_Header_Info *source) {
    *destination = *source;
    destination->name = source->name ? destination->nameStorage : NULL;
    destination->uuid = source->uuid ? destination->uuidStorage : NULL;
}

bool bsg_mach_headers_read_image_entry(const BSG_Dyld_Image_Info *images,
                                      uint32_t index, BSG_Dyld_Image_Info *entry) {
    if (!images || index > (UINTPTR_MAX - (uintptr_t)images) / sizeof(*images)) return false;
    return bsg_image_read((const void *)((uintptr_t)images + index * sizeof(*images)),
                          entry, sizeof(*entry));
}

// Copy a bounded batch instead of issuing one kernel call for every entry.
// The entries remain local copies; never dereference dyld's live array.
#define BSG_IMAGE_ENTRY_BATCH_SIZE 64
static bool read_image_batch(const BSG_Dyld_Image_Info *images, uint32_t index,
                             uint32_t count, BSG_Dyld_Image_Info *entries) {
    if (!images || index >= count ||
        index > (UINTPTR_MAX - (uintptr_t)images) / sizeof(*images)) return false;
    size_t length = count - index;
    if (length > BSG_IMAGE_ENTRY_BATCH_SIZE) length = BSG_IMAGE_ENTRY_BATCH_SIZE;
    return bsg_image_read((const void *)((uintptr_t)images + index * sizeof(*images)),
                          entries, length * sizeof(*images));
}

static bool is_main_header(const struct mach_header *header) {
    struct mach_header copy;
    return bsg_image_read(header, &copy, sizeof(copy)) && copy.filetype == MH_EXECUTE;
}


// dyld briefly publishes a NULL infoArray -- or one about to be replaced --
// while loading or unloading an image. Its own header documents exactly
// this: "If infoArray is NULL, it means it is being modified, come back
// later" (mach-o/dyld_images.h), and provides infoArrayChangeTimestamp for
// doing so. A handful of immediate retries covers the normal case (the
// window is a few pointer/count writes); if it is still unstable after
// that -- a stuck or pathologically slow update -- this gives up exactly
// as it always has (NULL, imageCount 0), so a frame that would have gone
// unresolved before still does, never anything worse. Bounded so a crash
// handler can never spin here indefinitely.
//
// Use separate checked reads: ordinary loads can be coalesced by the compiler.
// This is a bounded consistency check, not an atomic snapshot or a lifetime
// guarantee. Callers must still copy entries using checked reads because the
// array remains dyld-owned and can change after this function returns.
static const BSG_Dyld_Image_Info *get_images(uint32_t *count) {
    const BSG_Dyld_Image_Info *images = NULL;
    const BSG_Dyld_Image_Info *confirmedImages = NULL;
    uint32_t imageCount = 0;
    if (g_all_image_infos == NULL) {
        if (count != NULL) {
            *count = 0;
        }
        return NULL;
    }
    for (int attempt = 0; attempt < BSG_GET_IMAGES_MAX_ATTEMPTS; attempt++) {
        uint64_t timestampBefore = 0, timestampAfter = 0;
        images = NULL;
        imageCount = 0;
        // Test-only hook (NULL in production): stage 0 runs before an
        // attempt's reads, stage 1 after the array/count reads but before
        // the closing timestamp read, so a test can change dyld's struct at
        // exactly the points a real concurrent update could.
        if (g_get_images_hook != NULL) {
            g_get_images_hook(attempt, 0);
        }
        bool stable =
            bsg_image_read(&g_all_image_infos->infoArrayChangeTimestamp, &timestampBefore, sizeof(timestampBefore)) &&
            bsg_image_read(&g_all_image_infos->infoArray, &images, sizeof(images)) &&
            images != NULL &&
            bsg_image_read(&g_all_image_infos->infoArrayCount, &imageCount, sizeof(imageCount)) &&
            bsg_image_read(&g_all_image_infos->infoArray, &confirmedImages, sizeof(confirmedImages)) &&
            images == confirmedImages;
        if (g_get_images_hook != NULL) {
            g_get_images_hook(attempt, 1);
        }
        stable = stable &&
            bsg_image_read(&g_all_image_infos->infoArrayChangeTimestamp, &timestampAfter, sizeof(timestampAfter)) &&
            timestampBefore == timestampAfter;
        if (stable) {
            break; // Stable read: nothing changed while we were reading it.
        }
        images = NULL;
        imageCount = 0;
    }
    if (count != NULL) {
        *count = imageCount;
    }
    return images;
}

static bool images_ready(void) {
    bsg_mach_headers_initialize();
    return atomic_load_explicit(&g_initialization_state, memory_order_acquire) ==
           BSGImagesReady;
}

bool bsg_mach_headers_ready(void) {
    // Unlike images_ready(), never triggers initialization itself: a single
    // atomic load, safe to call from a crash handler for callers that must
    // not risk running register_dyld_images() (calloc, _dyld_get_image_header)
    // inline in that context -- see its callers in BSG_KSCrashReport.c.
    return atomic_load_explicit(&g_initialization_state, memory_order_acquire) ==
           BSGImagesReady;
}

void bsg_mach_headers_initialize(void) {
    if (atomic_load_explicit(&g_initialization_state, memory_order_acquire) !=
        BSGImagesUninitialized) {
        return;
    }
    int expected = BSGImagesUninitialized;
    if (!atomic_compare_exchange_strong(&g_initialization_state, &expected,
                                        BSGImagesInitializing)) {
        // A crash can interrupt initialization. Waiting here would deadlock.
        return;
    }
    if (g_initialization_hook != NULL) {
        g_initialization_hook();
    }
    register_dyld_images();
    atomic_store_explicit(&g_initialization_state,
                          g_all_image_infos ? BSGImagesReady : BSGImagesUninitialized,
                          memory_order_release);
}

const BSG_Dyld_Image_Info *bsg_mach_headers_get_images(uint32_t *count) {
    if (!images_ready()) {
        if (count != NULL) {
            *count = 0;
        }
        return NULL;
    }
    return get_images(count);
}

bool bsg_mach_headers_get_main_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }

    if (g_main_image != NULL) {
        return copy_cached_image(g_main_image, image);
    }

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    if (images == NULL) {
        return false;
    }

    for (uint32_t i = 0; i < count; i++) {
        BSG_Dyld_Image_Info entry;
        if (!bsg_mach_headers_read_image_entry(images, i, &entry)) break;
        const struct mach_header *header = entry.imageLoadAddress;
        if (header != NULL && is_main_header(header)) {
            return populate_image_info(header, 0,
                                       entry.imageFilePath, image);
        }
    }
    return false;
}

bool bsg_mach_headers_get_self_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }

    if (g_self_image != NULL) {
        return copy_cached_image(g_self_image, image);
    }

    // If dyld's array was unavailable during startup, retry without mutating
    // the published startup cache or allocating from the reporting path.
    const struct mach_header *header = (const void *)&__dso_handle;
    return populate_image_info(header, 0, NULL, image);
}

bool bsg_mach_headers_image_for_header(const struct mach_header *header,
                                       const char *name,
                                       BSG_Mach_Header_Info *image) {
    if (header == NULL || image == NULL) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }
    return populate_image_info(header, 0, name, image);
}

static bool find_shared_image(uintptr_t address, BSG_Mach_Header_Info *image) {
    if (atomic_flag_test_and_set_explicit(&g_shared_images_busy, memory_order_acquire)) {
        return false;
    }
    bool found = false;
    for (uint32_t i = 0; i < g_shared_image_count; i++) {
        if (image_contains_address(&g_shared_images[i], address)) {
            bsg_mach_headers_copy_image(image, &g_shared_images[i]);
            found = true;
            break;
        }
    }
    atomic_flag_clear_explicit(&g_shared_images_busy, memory_order_release);
    return found;
}

static void cache_shared_image(const BSG_Mach_Header_Info *image) {
    if (!(image->flags & MH_DYLIB_IN_CACHE) ||
        atomic_flag_test_and_set_explicit(&g_shared_images_busy, memory_order_acquire)) {
        return;
    }
    for (uint32_t i = 0; i < g_shared_image_count; i++) {
        if (g_shared_images[i].header == image->header) {
            atomic_flag_clear_explicit(&g_shared_images_busy, memory_order_release);
            return;
        }
    }
    if (g_shared_image_count < BSG_SHARED_IMAGE_CACHE_CAPACITY) {
        bsg_mach_headers_copy_image(&g_shared_images[g_shared_image_count++], image);
    }
    atomic_flag_clear_explicit(&g_shared_images_busy, memory_order_release);
}

// Reads the vmsize of an image's __TEXT segment. All command reads tolerate unmapping.
static bool header_text_size(const struct mach_header *header, uint64_t *textSize) {
    // __TEXT is normally one of the first commands. Copy one small prefix
    // instead of issuing a kernel read for every command on every candidate.
    union { struct mach_header_64 alignment; uint8_t bytes[512]; } prefix;
    size_t prefixSize = vm_page_size - (uintptr_t)header % vm_page_size;
    if (prefixSize > sizeof(prefix)) prefixSize = sizeof(prefix);
    if (prefixSize < sizeof(struct mach_header) ||
        !bsg_image_read(header, &prefix, prefixSize)) return false;
    const struct mach_header *copy = (const void *)prefix.bytes;
    size_t offset;
    switch (copy->magic) {
        case MH_MAGIC: case MH_CIGAM: offset = sizeof(struct mach_header); break;
        case MH_MAGIC_64: case MH_CIGAM_64: offset = sizeof(struct mach_header_64); break;
        default: return false;
    }
    if (copy->sizeofcmds > UINTPTR_MAX - (uintptr_t)header - offset) return false;
    size_t end = offset + copy->sizeofcmds;
    for (uint32_t i = 0; i < copy->ncmds; i++) {
        struct load_command lc;
        if (offset > end || end - offset < sizeof(lc)) return false;
        if (offset <= prefixSize && sizeof(lc) <= prefixSize - offset)
            memcpy(&lc, prefix.bytes + offset, sizeof(lc));
        else if (!bsg_image_read((const void *)((uintptr_t)header + offset), &lc, sizeof(lc))) return false;
        if (lc.cmdsize < sizeof(lc) || lc.cmdsize > end - offset) return false;
        union { struct segment_command_64 s64; struct segment_command s32; } segment;
        size_t size = lc.cmd == LC_SEGMENT_64 ? sizeof(segment.s64) :
                      lc.cmd == LC_SEGMENT ? sizeof(segment.s32) : 0;
        if (size) {
            if (lc.cmdsize < size) return false;
            if (offset <= prefixSize && size <= prefixSize - offset)
                memcpy(&segment, prefix.bytes + offset, size);
            else if (!bsg_image_read((const void *)((uintptr_t)header + offset), &segment, size)) return false;
            const char *name = lc.cmd == LC_SEGMENT_64 ? segment.s64.segname : segment.s32.segname;
            uint64_t sizeOfText = lc.cmd == LC_SEGMENT_64 ? segment.s64.vmsize : segment.s32.vmsize;
            if (!strncmp(name, SEG_TEXT, 16)) { *textSize = sizeOfText; return true; }
        }
        offset += lc.cmdsize;
    }
    return false;
}

// Only a matching image is fully parsed; all command reads tolerate unmapping.
static bool header_contains_address(const struct mach_header *header, uintptr_t address) {
    uint64_t textSize = 0;
    return address >= (uintptr_t)header && header_text_size(header, &textSize) &&
           address - (uintptr_t)header < textSize;
}

// ---------------------------------------------------------------------------
// Address-sorted image snapshot
//
// With only a few images cached at startup, every frame in a not-yet-cached
// image used to cost a scan of dyld's whole image array (one kernel read per
// candidate), i.e. O(frames x images) per report. Instead, the first such
// lookup reads the array ONCE, records each image's address range, sorts
// the ranges, and later lookups binary-search them (O(log images)).
//
// The snapshot is only a lookup index. It is stamped with three values read
// from dyld's all_image_infos -- infoArrayChangeTimestamp, the infoArray
// pointer and infoArrayCount -- and is rebuilt as soon as ANY of them
// differs from what it was built for. A negative answer ("not in any image")
// is only trusted while all three still match, so a dyld that fails to bump
// the timestamp on some image load/unload (on any OS version) is still
// caught by the pointer or the count changing. If dyld's list cannot be read
// consistently, or the index could not be built completely, the snapshot
// reports "unavailable" and the caller falls back to the full scan: it never
// answers "not found" from an incomplete or stale index. The full image
// info for a hit is still read with checked reads on demand, so an image
// unloaded after the snapshot was taken is never dereferenced.
//
// Async-signal-safe: no malloc and no locks. Memory comes from vm_allocate;
// access is guarded by a try-lock that is never waited on -- if it is busy
// (another thread, possibly suspended mid-lookup) the caller simply uses the
// slower scan, exactly as it did before.
#define BSG_IMAGE_SNAPSHOT_MAX_IMAGES 8192

typedef struct {
    uintptr_t start;
    uintptr_t end; // exclusive
    const char *name; // dyld's path pointer; only ever read with checked reads
    uint32_t slot;
} BSG_Image_Snapshot_Entry;

// What the snapshot (or a failed attempt to build one) is valid for.
typedef struct {
    uint64_t timestamp;
    const void *array;
    uint32_t count;
} BSG_Dyld_List_State;

typedef struct {
    BSG_Dyld_List_State state;
    uint32_t count;
    vm_size_t size; // allocation size, for vm_deallocate
    BSG_Image_Snapshot_Entry *entries; // sorted by start
    uint8_t *populated; // per slot: infos[slot] is valid
    BSG_Mach_Header_Info *infos; // per slot, parsed lazily on first hit
} BSG_Image_Snapshot;

static BSG_Image_Snapshot *g_image_snapshot;
static BSG_Dyld_List_State g_image_snapshot_failed_state;
static bool g_image_snapshot_failed;
static atomic_flag g_image_snapshot_busy = ATOMIC_FLAG_INIT;

enum { BSGSnapshotUnavailable, BSGSnapshotFound, BSGSnapshotNotFound };

static void snapshot_sift_down(BSG_Image_Snapshot_Entry *a, uint32_t root, uint32_t end) {
    while (2 * (uint64_t)root + 1 < end) {
        uint32_t child = 2 * root + 1;
        if (child + 1 < end && a[child].start < a[child + 1].start) child++;
        if (a[root].start >= a[child].start) return;
        BSG_Image_Snapshot_Entry tmp = a[root];
        a[root] = a[child];
        a[child] = tmp;
        root = child;
    }
}

// In-place heapsort: no allocation and no recursion, unlike qsort().
static void snapshot_sort(BSG_Image_Snapshot_Entry *a, uint32_t count) {
    for (uint32_t i = count / 2; i-- > 0;) snapshot_sift_down(a, i, count);
    for (uint32_t end = count; end-- > 1;) {
        BSG_Image_Snapshot_Entry tmp = a[0];
        a[0] = a[end];
        a[end] = tmp;
        snapshot_sift_down(a, 0, end);
    }
}

static void snapshot_free(BSG_Image_Snapshot *snapshot) {
    if (snapshot != NULL) {
        vm_deallocate(mach_task_self(), (vm_address_t)snapshot, snapshot->size);
    }
}

#define BSG_ALIGN8(x) (((x) + 7u) & ~(size_t)7u)

// One checked read covers infoArrayCount, infoArray and
// infoArrayChangeTimestamp (they sit within the first ~200 bytes of
// dyld_all_image_infos), so validating the snapshot costs a single kernel
// call per lookup instead of three. The fields are copied out of a local
// buffer, so the compiler cannot coalesce or re-read them. Like the separate
// reads this replaces, it is a bounded consistency check, not an atomic one:
// a concurrent dyld update can still land mid-copy, which is why snapshot_build()
// compares the state again after it has read the array. Fails if dyld's list
// is being modified (NULL infoArray) or unreadable.
#define BSG_DYLD_STATE_OFFSET offsetof(struct dyld_all_image_infos, infoArrayCount)
#define BSG_DYLD_STATE_END (offsetof(struct dyld_all_image_infos, infoArrayChangeTimestamp) + \
                            sizeof(((struct dyld_all_image_infos *)0)->infoArrayChangeTimestamp))
#define BSG_DYLD_STATE_LENGTH (BSG_DYLD_STATE_END - BSG_DYLD_STATE_OFFSET)
_Static_assert(BSG_DYLD_STATE_END > BSG_DYLD_STATE_OFFSET && BSG_DYLD_STATE_LENGTH <= 256,
               "dyld state fields must fit in one small read");

static bool read_dyld_list_state(BSG_Dyld_List_State *state) {
    memset(state, 0, sizeof(*state));
    if (g_all_image_infos == NULL) return false;
    uint8_t buffer[BSG_DYLD_STATE_LENGTH];
    if (!bsg_image_read((const uint8_t *)g_all_image_infos + BSG_DYLD_STATE_OFFSET,
                        buffer, sizeof(buffer))) {
        return false;
    }
    const BSG_Dyld_Image_Info *array = NULL;
    uint32_t count = 0;
    uint64_t timestamp = 0;
    memcpy(&count, buffer + (offsetof(struct dyld_all_image_infos, infoArrayCount) - BSG_DYLD_STATE_OFFSET),
           sizeof(count));
    memcpy(&array, buffer + (offsetof(struct dyld_all_image_infos, infoArray) - BSG_DYLD_STATE_OFFSET),
           sizeof(array));
    memcpy(&timestamp, buffer + (offsetof(struct dyld_all_image_infos, infoArrayChangeTimestamp) - BSG_DYLD_STATE_OFFSET),
           sizeof(timestamp));
    if (array == NULL) return false;
    state->timestamp = timestamp;
    state->array = array;
    state->count = count;
    return true;
}

static bool dyld_list_state_equal(const BSG_Dyld_List_State *a, const BSG_Dyld_List_State *b) {
    return a->timestamp == b->timestamp && a->array == b->array && a->count == b->count;
}

static BSG_Image_Snapshot *snapshot_build(BSG_Dyld_List_State *stateOut) {
    BSG_Dyld_List_State before, after;
    if (!read_dyld_list_state(&before)) {
        return NULL;
    }
    *stateOut = before;
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = get_images(&count);
    // The index must describe exactly the list that was stamped above.
    if (images == NULL || count == 0 || count > BSG_IMAGE_SNAPSHOT_MAX_IMAGES ||
        (const void *)images != before.array || count != before.count) {
        return NULL;
    }
    size_t entriesOffset = BSG_ALIGN8(sizeof(BSG_Image_Snapshot));
    size_t populatedOffset = BSG_ALIGN8(entriesOffset + count * sizeof(BSG_Image_Snapshot_Entry));
    size_t infosOffset = BSG_ALIGN8(populatedOffset + count);
    size_t total = infosOffset + count * sizeof(BSG_Mach_Header_Info);
    vm_address_t region = 0;
    if (vm_allocate(mach_task_self(), &region, total, VM_FLAGS_ANYWHERE) != KERN_SUCCESS) {
        return NULL;
    }
    // vm_allocate returns zero-filled pages, and the (large) infos area is
    // only touched for images that actually appear in a backtrace.
    BSG_Image_Snapshot *snapshot = (BSG_Image_Snapshot *)region;
    snapshot->size = total;
    snapshot->entries = (BSG_Image_Snapshot_Entry *)(region + entriesOffset);
    snapshot->populated = (uint8_t *)(region + populatedOffset);
    snapshot->infos = (BSG_Mach_Header_Info *)(region + infosOffset);

    uint32_t used = 0;
    BSG_Dyld_Image_Info batch[BSG_IMAGE_ENTRY_BATCH_SIZE];
    for (uint32_t i = 0; i < count; i++) {
        if (i % BSG_IMAGE_ENTRY_BATCH_SIZE == 0 &&
            !read_image_batch(images, i, count, batch)) {
            // An unreadable part of dyld's array would leave images missing
            // from the index, and a missing image would be reported as
            // "not found". Never publish an incomplete index.
            snapshot_free(snapshot);
            return NULL;
        }
        BSG_Dyld_Image_Info entry = batch[i % BSG_IMAGE_ENTRY_BATCH_SIZE];
        const struct mach_header *header = entry.imageLoadAddress;
        uint64_t textSize = 0;
        if (header == NULL || !header_text_size(header, &textSize) || textSize == 0 ||
            textSize > UINTPTR_MAX - (uintptr_t)header) continue;
        snapshot->entries[used].start = (uintptr_t)header;
        snapshot->entries[used].end = (uintptr_t)header + (uintptr_t)textSize;
        snapshot->entries[used].name = entry.imageFilePath;
        snapshot->entries[used].slot = used;
        used++;
    }
    // If dyld changed the list while we were reading it, the index may mix
    // old and new images: discard it rather than trust it.
    if (!read_dyld_list_state(&after) || !dyld_list_state_equal(&after, &before)) {
        snapshot_free(snapshot);
        return NULL;
    }
    snapshot->state = before;
    snapshot->count = used;
    snapshot_sort(snapshot->entries, used);
    return snapshot;
}

static int snapshot_find(uintptr_t address, BSG_Mach_Header_Info *image) {
    if (g_all_image_infos == NULL ||
        atomic_flag_test_and_set_explicit(&g_image_snapshot_busy, memory_order_acquire)) {
        return BSGSnapshotUnavailable;
    }
    int result = BSGSnapshotUnavailable;
    BSG_Dyld_List_State current;
    if (read_dyld_list_state(&current)) {
        if (g_image_snapshot == NULL ||
            !dyld_list_state_equal(&g_image_snapshot->state, &current)) {
            if (!(g_image_snapshot_failed &&
                  dyld_list_state_equal(&g_image_snapshot_failed_state, &current))) {
                BSG_Dyld_List_State builtFor;
                memset(&builtFor, 0, sizeof(builtFor));
                BSG_Image_Snapshot *fresh = snapshot_build(&builtFor);
                snapshot_free(g_image_snapshot);
                g_image_snapshot = fresh;
                // Do not retry (and pay for a failed build) on every frame
                // while dyld's list stays unreadable/unstable in this state.
                g_image_snapshot_failed = fresh == NULL;
                g_image_snapshot_failed_state = builtFor;
            }
        }
        BSG_Image_Snapshot *snapshot = g_image_snapshot;
        if (snapshot != NULL && dyld_list_state_equal(&snapshot->state, &current)) {
            result = BSGSnapshotNotFound;
            uint32_t low = 0, high = snapshot->count; // find last entry with start <= address
            while (low < high) {
                uint32_t mid = low + (high - low) / 2;
                if (snapshot->entries[mid].start <= address) low = mid + 1; else high = mid;
            }
            if (low > 0 && address < snapshot->entries[low - 1].end) {
                const BSG_Image_Snapshot_Entry *hit = &snapshot->entries[low - 1];
                if (!snapshot->populated[hit->slot]) {
                    if (populate_image_info((const struct mach_header *)hit->start, 0, hit->name,
                                            &snapshot->infos[hit->slot])) {
                        snapshot->populated[hit->slot] = 1;
                    }
                }
                if (snapshot->populated[hit->slot]) {
                    bsg_mach_headers_copy_image(image, &snapshot->infos[hit->slot]);
                    result = BSGSnapshotFound;
                } else {
                    result = BSGSnapshotUnavailable; // e.g. unloaded since: let the scan decide
                }
            }
        }
    }
    atomic_flag_clear_explicit(&g_image_snapshot_busy, memory_order_release);
    return result;
}

bool bsg_mach_headers_image_at_address(uintptr_t address,
                                       BSG_Mach_Header_Info *image) {
    if (image == NULL || address == 0) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }

    BSG_Mach_Image_Node *cached = find_cached_image_at_address(address);
    if (cached != NULL) {
        return copy_cached_image(cached, image);
    }

    if (find_shared_image(address, image)) {
        return true;
    }

    int snapshotResult = snapshot_find(address, image);
    if (snapshotResult == BSGSnapshotFound) {
        cache_shared_image(image);
        return true;
    }
    if (snapshotResult == BSGSnapshotNotFound) {
        return false;
    }

    // Do not call dladdr() here. This function is used while writing fatal
    // crash reports, where another suspended thread may hold dyld's internal
    // lock. Resolve uncached addresses from dyld's published image array
    // instead, which does not acquire that lock.

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    if (images == NULL) {
        return false;
    }

    BSG_Dyld_Image_Info entries[BSG_IMAGE_ENTRY_BATCH_SIZE];
    for (uint32_t i = 0; i < count; i++) {
        if (i % BSG_IMAGE_ENTRY_BATCH_SIZE == 0 &&
            !read_image_batch(images, i, count, entries)) break;
        BSG_Dyld_Image_Info entry = entries[i % BSG_IMAGE_ENTRY_BATCH_SIZE];
        const struct mach_header *header = entry.imageLoadAddress;
        if (header == NULL) {
            continue;
        }
        if (header_contains_address(header, address) &&
            populate_image_info(header, 0,
                                entry.imageFilePath, image)) {
            cache_shared_image(image);
            return true;
        }
    }

    return false;
}

bool bsg_mach_headers_image_is_current(const BSG_Mach_Header_Info *image) {
    if (image == NULL || image->header == NULL || image->uuid == NULL ||
        g_all_image_infos == NULL ||
        atomic_flag_test_and_set_explicit(&g_image_snapshot_busy, memory_order_acquire)) {
        return false;
    }
    bool current = false;
    BSG_Dyld_List_State state;
    const BSG_Image_Snapshot *snapshot = g_image_snapshot;
    if (snapshot != NULL && read_dyld_list_state(&state) &&
        dyld_list_state_equal(&snapshot->state, &state)) {
        const uintptr_t start = (uintptr_t)image->header;
        uint32_t low = 0, high = snapshot->count; // last entry with start <= header
        while (low < high) {
            uint32_t mid = low + (high - low) / 2;
            if (snapshot->entries[mid].start <= start) low = mid + 1; else high = mid;
        }
        if (low > 0 && snapshot->entries[low - 1].start == start) {
            const uint32_t slot = snapshot->entries[low - 1].slot;
            const BSG_Mach_Header_Info *known = &snapshot->infos[slot];
            current = snapshot->populated[slot] && known->uuid != NULL &&
                      known->imageSize == image->imageSize &&
                      memcmp(known->uuid, image->uuid, 16) == 0;
        }
    }
    atomic_flag_clear_explicit(&g_image_snapshot_busy, memory_order_release);
    return current;
}

bool bsg_mach_headers_image_named(const char *imageName, bool exactMatch,
                                  BSG_Mach_Header_Info *image) {
    if (imageName == NULL) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }

    BSG_Mach_Image_Node *cached = find_cached_image_named(imageName, exactMatch);
    if (cached != NULL) {
        if (image != NULL) {
            return copy_cached_image(cached, image);
        }
        return true;
    }

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    if (images == NULL) {
        return false;
    }

    BSG_Dyld_Image_Info entries[BSG_IMAGE_ENTRY_BATCH_SIZE];
    for (uint32_t i = 0; i < count; i++) {
        if (i % BSG_IMAGE_ENTRY_BATCH_SIZE == 0 &&
            !read_image_batch(images, i, count, entries)) break;
        BSG_Dyld_Image_Info entry = entries[i % BSG_IMAGE_ENTRY_BATCH_SIZE];
        char path[1024];
        if (!bsg_image_read_string(entry.imageFilePath, path, sizeof(path))) continue;
        const char *candidateName = path;
        if (candidateName == NULL) {
            continue;
        }

        bool matches = exactMatch ? strcmp(candidateName, imageName) == 0
                                  : strstr(candidateName, imageName) != NULL;
        if (!matches) {
            continue;
        }

        const struct mach_header *header = entry.imageLoadAddress;
        if (header != NULL) {
            if (image == NULL) {
                return true;
            }
            if (populate_image_info(header, 0,
                                    candidateName, image)) {
                return true;
            }
        }
    }

    return false;
}

uintptr_t bsg_mach_headers_first_cmd_after_header(const struct mach_header *const header) {
    if (header == NULL) {
        return 0;
    }

    uint32_t magic;
    if (!bsg_image_read(header, &magic, sizeof(magic))) return 0;
    switch (magic) {
        case MH_MAGIC:
        case MH_CIGAM:
            return (uintptr_t)(header + 1);
        case MH_MAGIC_64:
        case MH_CIGAM_64:
            return (uintptr_t)(((const struct mach_header_64 *)header) + 1);
        default:
            return 0;
    }
}

bool bsg_mach_headers_get_crash_info_message(const BSG_Mach_Header_Info *image,
                                             char *message, size_t capacity) {
    struct mach_header header;
    if (!bsg_image_read(image->header, &header, sizeof(header))) return false;
    uintptr_t command = bsg_mach_headers_first_cmd_after_header(image->header);
    if (!command || header.sizeofcmds > UINTPTR_MAX - command) return false;
    uintptr_t end = command + header.sizeofcmds;
    uintptr_t sectionAddress = 0;
    for (uint32_t i = 0; i < header.ncmds; i++) {
        struct load_command lc;
        if (command > end || end - command < sizeof(lc) ||
            !bsg_image_read((void *)command, &lc, sizeof(lc)) ||
            lc.cmdsize < sizeof(lc) || lc.cmdsize > end - command) return false;
        if (lc.cmd == LC_SEGMENT_64) {
            struct segment_command_64 segment;
            if (lc.cmdsize < sizeof(segment) ||
                !bsg_image_read((void *)command, &segment, sizeof(segment)) ||
                segment.nsects > (lc.cmdsize - sizeof(segment)) / sizeof(struct section_64)) return false;
            for (uint32_t j = 0; j < segment.nsects; j++) {
                struct section_64 section;
                if (!bsg_image_read((void *)(command + sizeof(segment) + j * sizeof(section)),
                                    &section, sizeof(section))) return false;
                if (!strncmp(section.sectname, CRASHREPORTER_ANNOTATIONS_SECTION, sizeof(section.sectname)))
                    sectionAddress = section.addr + (uintptr_t)image->slide;
            }
        } else if (lc.cmd == LC_SEGMENT) {
            struct segment_command segment;
            if (lc.cmdsize < sizeof(segment) ||
                !bsg_image_read((void *)command, &segment, sizeof(segment)) ||
                segment.nsects > (lc.cmdsize - sizeof(segment)) / sizeof(struct section)) return false;
            for (uint32_t j = 0; j < segment.nsects; j++) {
                struct section section;
                if (!bsg_image_read((void *)(command + sizeof(segment) + j * sizeof(section)),
                                    &section, sizeof(section))) return false;
                if (!strncmp(section.sectname, CRASHREPORTER_ANNOTATIONS_SECTION, sizeof(section.sectname)))
                    sectionAddress = section.addr + (uintptr_t)image->slide;
            }
        }
        command += lc.cmdsize;
    }
    struct crashreporter_annotations_t annotation;
    if (!sectionAddress ||
        !bsg_image_read((void *)sectionAddress, &annotation, sizeof(annotation)) ||
        annotation.version > CRASHREPORTER_ANNOTATIONS_VERSION) return false;
    return bsg_image_read_string((const char *)(uintptr_t)annotation.message, message, capacity);
}

// Test hooks require quiescent readers; never reset the cache in production.
void bsg_test_support_mach_headers_reset(void) {
    clear_cached_images();
    g_all_image_infos = NULL;
    g_shared_image_count = 0;
    atomic_flag_clear(&g_shared_images_busy);
    g_initialization_hook = NULL;
    g_get_images_hook = NULL;
    snapshot_free(g_image_snapshot);
    g_image_snapshot = NULL;
    g_image_snapshot_failed = false;
    atomic_flag_clear(&g_image_snapshot_busy);
    atomic_store(&g_initialization_state, BSGImagesUninitialized);
}

uint32_t bsg_test_support_mach_headers_cached_image_count(void) {
    return atomic_load(&g_cached_image_count);
}

void bsg_test_support_mach_headers_set_initialization_hook(void (*hook)(void)) {
    g_initialization_hook = hook;
}

void bsg_test_support_mach_headers_set_get_images_hook(void (*hook)(int attempt, int stage)) {
    g_get_images_hook = hook;
}

void bsg_test_support_mach_headers_set_dyld_info(const struct dyld_all_image_infos *info) {
    g_all_image_infos = info;
    atomic_store(&g_initialization_state, BSGImagesReady);
}

static void register_dyld_images(void) {
    task_dyld_info_data_t dyld_info = {0};
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_DYLD_INFO,
                                     (task_info_t)&dyld_info, &count);
    if (result != KERN_SUCCESS || dyld_info.all_image_info_addr == 0) {
        BSG_KSLOG_ERROR("task_info TASK_DYLD_INFO failed: %s",
                        mach_error_string(result));
        return;
    }

    g_all_image_infos = (const void *)dyld_info.all_image_info_addr;

    if (g_all_image_infos->dyldImageLoadAddress != NULL) {
        cache_image_for_header(g_all_image_infos->dyldImageLoadAddress,
                               g_all_image_infos->dyldPath, &g_dyld_image);
    }

    const struct mach_header *mainHeader = NULL;
    uint32_t imageCount = 0;
    const BSG_Dyld_Image_Info *images = get_images(&imageCount);
    for (uint32_t i = 0; images != NULL && i < imageCount; i++) {
        BSG_Dyld_Image_Info entry;
        if (!bsg_mach_headers_read_image_entry(images, i, &entry)) break;
        const struct mach_header *header = entry.imageLoadAddress;
        if (header != NULL && is_main_header(header)) {
            mainHeader = header;
            cache_image_for_header(header, entry.imageFilePath, &g_main_image);
            break;
        }
    }

    if (mainHeader == NULL) {
        mainHeader = _dyld_get_image_header(0);
        if (mainHeader != NULL) {
            cache_image_for_header(mainHeader, _dyld_get_image_name(0), &g_main_image);
        }
    }

    // A NULL name here would make cache_image_for_header() fall back to
    // get_path(), which walks the whole dyld image array just to find
    // Bugsnag's own path -- fine at startup, not crash time, but needless
    // when dladdr() can answer the same question directly from the address
    // we already have, with no array walk at all.
    Dl_info selfInfo;
    const char *selfPath = dladdr(&__dso_handle, &selfInfo) ? selfInfo.dli_fname : NULL;
    cache_image_for_header((const struct mach_header *)&__dso_handle, selfPath,
                           &g_self_image);
}

static bool populate_image_info(const struct mach_header *header, intptr_t unusedSlide,
                                const char *name, BSG_Mach_Header_Info *info) {
    (void)unusedSlide;
    if (!header || !info) return false;
    memset(info, 0, sizeof(*info));
    struct mach_header copy;
    if (!bsg_image_read(header, &copy, sizeof(copy))) return false;
    uintptr_t command = bsg_mach_headers_first_cmd_after_header(header);
    if (!command || copy.sizeofcmds > UINTPTR_MAX - command) return false;
    const uintptr_t end = command + copy.sizeofcmds;
    bool hasText = false;
    for (uint32_t i = 0; i < copy.ncmds; i++) {
        struct load_command lc;
        if (command > end || end - command < sizeof(lc) ||
            !bsg_image_read((void *)command, &lc, sizeof(lc)) ||
            lc.cmdsize < sizeof(lc) || lc.cmdsize > end - command) return false;
        if (lc.cmd == LC_SEGMENT_64) {
            struct segment_command_64 segment;
            if (lc.cmdsize < sizeof(segment) ||
                !bsg_image_read((void *)command, &segment, sizeof(segment))) return false;
            if (!strncmp(segment.segname, SEG_TEXT, sizeof(segment.segname))) {
                info->imageSize = segment.vmsize;
                info->imageVmAddr = segment.vmaddr;
                hasText = true;
            }
        } else if (lc.cmd == LC_SEGMENT) {
            struct segment_command segment;
            if (lc.cmdsize < sizeof(segment) ||
                !bsg_image_read((void *)command, &segment, sizeof(segment))) return false;
            if (!strncmp(segment.segname, SEG_TEXT, sizeof(segment.segname))) {
                info->imageSize = segment.vmsize;
                info->imageVmAddr = segment.vmaddr;
                hasText = true;
            }
        } else if (lc.cmd == LC_UUID) {
            struct uuid_command uuid;
            if (lc.cmdsize < sizeof(uuid) ||
                !bsg_image_read((void *)command, &uuid, sizeof(uuid))) return false;
            memcpy(info->uuidStorage, uuid.uuid, sizeof(info->uuidStorage));
            info->uuid = info->uuidStorage;
        }
        command += lc.cmdsize;
    }
    const char *path = name ? name : get_path(header);
    if (!hasText || !bsg_image_read_string(path, info->nameStorage, sizeof(info->nameStorage)))
        return false;
    // Do not return a header which disappeared during parsing.
    struct mach_header verify;
    if (!bsg_image_read(header, &verify, sizeof(verify)) ||
        memcmp(&copy, &verify, sizeof(copy))) return false;
    info->header = header; // identity only; consumers must not dereference it
    info->name = info->nameStorage;
    info->slide = (intptr_t)((uintptr_t)header - info->imageVmAddr);
    info->flags = copy.flags;
    info->cpuType = copy.cputype;
    info->cpuSubtype = copy.cpusubtype;
    return true;
}

static bool image_contains_address(const BSG_Mach_Header_Info *image,
                                   uintptr_t address) {
    if (image == NULL || image->header == NULL || image->imageSize == 0) {
        return false;
    }
    uintptr_t imageStart = (uintptr_t)image->header;
    return address >= imageStart && address - imageStart < image->imageSize;
}

static BSG_Mach_Image_Node *find_cached_image_at_address(uintptr_t address) {
    for (BSG_Mach_Image_Node *node = g_cached_images_head; node != NULL;
         node = node->next) {
        if (image_contains_address(&node->info, address)) {
            return node;
        }
    }
    return NULL;
}

static BSG_Mach_Image_Node *find_cached_image_named(const char *imageName,
                                                    bool exactMatch) {
    for (BSG_Mach_Image_Node *node = g_cached_images_head; node != NULL;
         node = node->next) {
        const char *candidate = node->info.name;
        if (candidate == NULL) {
            continue;
        }
        if (exactMatch) {
            if (strcmp(candidate, imageName) == 0) {
                return node;
            }
        } else if (strstr(candidate, imageName) != NULL) {
            return node;
        }
    }
    return NULL;
}

static bool copy_cached_image(const BSG_Mach_Image_Node *node,
                              BSG_Mach_Header_Info *image) {
    if (node == NULL || image == NULL) {
        return false;
    }
    bsg_mach_headers_copy_image(image, &node->info);
    return true;
}

static bool cache_image(const BSG_Mach_Header_Info *image,
                        BSG_Mach_Image_Node **slot) {
    if (image == NULL || image->header == NULL) {
        return false;
    }

    for (BSG_Mach_Image_Node *node = g_cached_images_head; node != NULL;
         node = node->next) {
        if (node->info.header == image->header) {
            bsg_mach_headers_copy_image(&node->info, image);
            if (slot != NULL) {
                *slot = node;
            }
            return true;
        }
    }

    BSG_Mach_Image_Node *node = calloc(1, sizeof(*node));
    if (node == NULL) {
        return false;
    }

    bsg_mach_headers_copy_image(&node->info, image);
    if (g_cached_images_tail != NULL) {
        g_cached_images_tail->next = node;
    } else {
        g_cached_images_head = node;
    }
    g_cached_images_tail = node;
    atomic_fetch_add(&g_cached_image_count, 1);

    if (slot != NULL) {
        *slot = node;
    }
    return true;
}

static bool cache_image_for_header(const struct mach_header *header,
                                   const char *name,
                                   BSG_Mach_Image_Node **slot) {
    if (header == NULL) {
        return false;
    }

    BSG_Mach_Header_Info image;
    if (!populate_image_info(header, 0, name, &image)) {
        return false;
    }
    return cache_image(&image, slot);
}

static void clear_cached_images(void) {
    BSG_Mach_Image_Node *node = g_cached_images_head;
    while (node != NULL) {
        BSG_Mach_Image_Node *next = node->next;
        free(node);
        node = next;
    }
    g_cached_images_head = NULL;
    g_cached_images_tail = NULL;
    g_main_image = NULL;
    g_self_image = NULL;
    g_dyld_image = NULL;
    atomic_store(&g_cached_image_count, 0);
}

static const char *get_path(const struct mach_header *header) {
    if (g_all_image_infos != NULL &&
        header == g_all_image_infos->dyldImageLoadAddress) {
        return g_all_image_infos->dyldPath;
    }
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = get_images(&count);
    BSG_Dyld_Image_Info entries[BSG_IMAGE_ENTRY_BATCH_SIZE];
    for (uint32_t i = 0; i < count; i++) {
        if (i % BSG_IMAGE_ENTRY_BATCH_SIZE == 0 &&
            !read_image_batch(images, i, count, entries)) break;
        BSG_Dyld_Image_Info entry = entries[i % BSG_IMAGE_ENTRY_BATCH_SIZE];
        if (entry.imageLoadAddress == header) {
            return entry.imageFilePath;
        }
    }
    return NULL;
}

