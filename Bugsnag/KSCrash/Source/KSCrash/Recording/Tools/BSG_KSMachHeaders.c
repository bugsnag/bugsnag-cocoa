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

static bool is_main_header(const struct mach_header *header) {
    struct mach_header copy;
    return bsg_image_read(header, &copy, sizeof(copy)) && copy.filetype == MH_EXECUTE;
}


// dyld may temporarily publish a NULL array while changing the image list.
// Never return a nonzero count without an array. The array remains dyld-owned.
static const BSG_Dyld_Image_Info *get_images(uint32_t *count) {
    const BSG_Dyld_Image_Info *images = NULL;
    uint32_t imageCount = 0;
    if (g_all_image_infos != NULL) {
        images = g_all_image_infos->infoArray;
        if (images != NULL) {
            imageCount = g_all_image_infos->infoArrayCount;
            if (images != g_all_image_infos->infoArray) {
                images = NULL;
                imageCount = 0;
            }
        }
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

bool bsg_mach_headers_get_dyld_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    if (!images_ready()) {
        return false;
    }

    if (g_dyld_image != NULL) {
        return copy_cached_image(g_dyld_image, image);
    }

    if (g_all_image_infos == NULL || g_all_image_infos->dyldImageLoadAddress == NULL) {
        return false;
    }

    return populate_image_info(g_all_image_infos->dyldImageLoadAddress,
                               0,
                               g_all_image_infos->dyldPath, image);
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

bool bsg_mach_headers_get_cached_image(uint32_t index, BSG_Mach_Header_Info *image) {
    if (image == NULL || !images_ready()) {
        return false;
    }
    for (BSG_Mach_Image_Node *node = g_cached_images_head; node != NULL;
         node = node->next) {
        if (index == 0) {
            return copy_cached_image(node, image);
        }
        index--;
    }
    if (atomic_flag_test_and_set_explicit(&g_shared_images_busy, memory_order_acquire)) {
        return false;
    }
    bool found = index < g_shared_image_count;
    if (found) {
        bsg_mach_headers_copy_image(image, &g_shared_images[index]);
    }
    atomic_flag_clear_explicit(&g_shared_images_busy, memory_order_release);
    return found;
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

// Only a matching image is fully parsed; all command reads tolerate unmapping.
static bool header_contains_address(const struct mach_header *header, uintptr_t address) {
    if (address < (uintptr_t)header) return false;
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
            if (!strncmp(name, SEG_TEXT, 16)) return address - (uintptr_t)header < sizeOfText;
        }
        offset += lc.cmdsize;
    }
    return false;
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

    // Do not call dladdr() here. This function is used while writing fatal
    // crash reports, where another suspended thread may hold dyld's internal
    // lock. Resolve uncached addresses from dyld's published image array
    // instead, which does not acquire that lock.

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    if (images == NULL) {
        return false;
    }

    BSG_Dyld_Image_Info entries[64];
    for (uint32_t i = 0; i < count; i++) {
        if (i % 64 == 0) {
            size_t length = count - i;
            if (length > 64) length = 64;
            if (i > (UINTPTR_MAX - (uintptr_t)images) / sizeof(*images) ||
                !bsg_image_read((const void *)((uintptr_t)images + i * sizeof(*images)),
                                entries, length * sizeof(*images))) break;
        }
        BSG_Dyld_Image_Info entry = entries[i % 64];
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

    for (uint32_t i = 0; i < count; i++) {
        BSG_Dyld_Image_Info entry;
        if (!bsg_mach_headers_read_image_entry(images, i, &entry)) break;
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
    atomic_store(&g_initialization_state, BSGImagesUninitialized);
}

uint32_t bsg_test_support_mach_headers_cached_image_count(void) {
    return atomic_load(&g_cached_image_count);
}

void bsg_test_support_mach_headers_set_initialization_hook(void (*hook)(void)) {
    g_initialization_hook = hook;
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

    cache_image_for_header((const struct mach_header *)&__dso_handle, NULL,
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
    for (uint32_t i = 0; i < count; i++) {
        BSG_Dyld_Image_Info entry;
        if (!bsg_mach_headers_read_image_entry(images, i, &entry)) break;
        if (entry.imageLoadAddress == header) {
            return entry.imageFilePath;
        }
    }
    return NULL;
}
