//
//  BSG_KSMachHeaders.c
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Current implementation created by Alex Cohen on 30/08/2026.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#include "BSG_KSMachHeaders.h"

#include "BSG_KSLogger.h"
#include "BSG_KSMach.h"

#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/loader.h>
#include <mach/task.h>
#include <stdatomic.h>
#include <string.h>

extern struct mach_header __dso_handle;

// Copied from https://github.com/apple/swift/blob/swift-5.0-RELEASE/include/swift/Runtime/Debug.h#L28-L40

#define CRASHREPORTER_ANNOTATIONS_VERSION 7
#define CRASHREPORTER_ANNOTATIONS_SECTION "__crash_info"

// Large enough for all images in normal applications while keeping lookup
// storage bounded and allocation-free in crash handlers.
#define BSG_MACH_HEADERS_MAX_CACHE_ENTRIES 2048
#define BSG_MACH_HEADERS_MAX_SEGMENTS_PER_IMAGE 16

struct crashreporter_annotations_t {
    uint64_t version;
    uint64_t message;
    uint64_t signature_string;
    uint64_t backtrace;
    uint64_t message2;
    uint64_t thread;
    uint64_t dialog_mode;
    uint64_t abort_cause;
};

typedef struct {
    uintptr_t start;
    uintptr_t end;
} BSG_Mach_Segment_Range;

typedef struct {
    uintptr_t startAddress;
    uintptr_t endAddress;
    BSG_Mach_Header_Info image;
    BSG_Mach_Segment_Range segments[BSG_MACH_HEADERS_MAX_SEGMENTS_PER_IMAGE];
    uint8_t segmentCount;
} BSG_Mach_Image_Range;

typedef struct {
    BSG_Mach_Image_Range entries[BSG_MACH_HEADERS_MAX_CACHE_ENTRIES];
    uint32_t count;
} BSG_Mach_Image_Cache;

static BSG_Mach_Image_Cache g_cache_storage;
// NULL means another caller currently has exclusive access to the cache.
static _Atomic(BSG_Mach_Image_Cache *) g_cache;

// dyld owns this append-only array. New entries become visible only after
// their contents are initialized, so readers can safely iterate a snapshot in
// crash handlers. See https://github.com/kstenerud/KSCrash/pull/655.
static _Atomic(struct dyld_all_image_infos *) g_all_image_infos;
static _Atomic(bool) g_initialized;
static dyld_image_notifier g_original_notifier;

static bool populate_cache_entry(const struct mach_header *header,
                                 const char *name, BSG_Mach_Image_Range *entry);
static bool address_in_segments(const BSG_Mach_Image_Range *entry,
                                uintptr_t address);
static int32_t find_cached_header(const BSG_Mach_Image_Cache *cache,
                                  const struct mach_header *header);
static void insert_cache_entry(BSG_Mach_Image_Cache *cache,
                               const BSG_Mach_Image_Range *entry);
static bool linear_scan_for_address(uintptr_t address,
                                    BSG_Mach_Image_Range *entry);
static const char *dyld_path(void);

uintptr_t bsg_mach_headers_first_cmd_after_header(
    const struct mach_header *const header) {
    if (header == NULL) {
        return 0;
    }
    switch (header->magic) {
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

static bool populate_cache_entry(const struct mach_header *header,
                                 const char *name,
                                 BSG_Mach_Image_Range *entry) {
    *entry = (BSG_Mach_Image_Range){.image = {
                                        .header = header,
                                        .name = name,
                                    }};

    uintptr_t cmdPtr = bsg_mach_headers_first_cmd_after_header(header);
    if (cmdPtr == 0) {
        BSG_KSLOG_ERROR("Invalid mach header @ %p", header);
        return false;
    }

    uint64_t minAddress = UINT64_MAX;
    uint64_t maxAddress = 0;
    uint8_t segmentCount = 0;
    bool foundText = false;

    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        const struct load_command *loadCmd = (const void *)cmdPtr;
        if (loadCmd->cmdsize < sizeof(*loadCmd)) {
            BSG_KSLOG_ERROR("Invalid mach load command @ %p", loadCmd);
            return false;
        }

        uint64_t vmaddr = 0;
        uint64_t vmsize = 0;
        uint64_t filesize = 0;
        const char *segname = NULL;

        switch (loadCmd->cmd) {
        case LC_SEGMENT: {
            const struct segment_command *segment = (const void *)loadCmd;
            vmaddr = segment->vmaddr;
            vmsize = segment->vmsize;
            filesize = segment->filesize;
            segname = segment->segname;
            break;
        }
        case LC_SEGMENT_64: {
            const struct segment_command_64 *segment = (const void *)loadCmd;
            vmaddr = segment->vmaddr;
            vmsize = segment->vmsize;
            filesize = segment->filesize;
            segname = segment->segname;
            break;
        }
        case LC_UUID: {
            const struct uuid_command *uuidCommand = (const void *)loadCmd;
            entry->image.uuid = uuidCommand->uuid;
            break;
        }
        default:
            break;
        }

        if (segname != NULL) {
            if (strncmp(segname, SEG_TEXT,
                        sizeof(((struct segment_command *)0)->segname)) == 0) {
                entry->image.imageVmAddr = vmaddr;
                entry->image.imageSize = vmsize;
                entry->image.slide = (intptr_t)header - (intptr_t)vmaddr;
                foundText = true;
            }

            // Exclude __PAGEZERO and other segments with no file-backed
            // content.
            if (vmsize > 0 && filesize > 0) {
                if (vmaddr < minAddress) {
                    minAddress = vmaddr;
                }
                if (vmaddr + vmsize > maxAddress) {
                    maxAddress = vmaddr + vmsize;
                }
                if (segmentCount < BSG_MACH_HEADERS_MAX_SEGMENTS_PER_IMAGE) {
                    entry->segments[segmentCount++] = (BSG_Mach_Segment_Range){
                        .start = (uintptr_t)vmaddr,
                        .end = (uintptr_t)(vmaddr + vmsize),
                    };
                }
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }

    if (!foundText || segmentCount == 0) {
        return false;
    }

    uintptr_t slide = (uintptr_t)entry->image.slide;
    for (uint8_t i = 0; i < segmentCount; i++) {
        entry->segments[i].start += slide;
        entry->segments[i].end += slide;
    }
    entry->startAddress = (uintptr_t)minAddress + slide;
    entry->endAddress = (uintptr_t)maxAddress + slide;
    entry->segmentCount = segmentCount;
    return true;
}

static bool address_in_segments(const BSG_Mach_Image_Range *entry,
                                uintptr_t address) {
    for (uint8_t i = 0; i < entry->segmentCount; i++) {
        if (address >= entry->segments[i].start &&
            address < entry->segments[i].end) {
            return true;
        }
    }
    return false;
}

static int32_t binary_search_cache(const BSG_Mach_Image_Cache *cache,
                                   uintptr_t address) {
    int32_t left = 0;
    int32_t right = (int32_t)cache->count - 1;
    int32_t result = -1;
    while (left <= right) {
        int32_t middle = left + (right - left) / 2;
        if (cache->entries[middle].startAddress <= address) {
            result = middle;
            left = middle + 1;
        } else {
            right = middle - 1;
        }
    }
    return result;
}

static int32_t find_cached_header(const BSG_Mach_Image_Cache *cache,
                                  const struct mach_header *header) {
    for (uint32_t i = 0; i < cache->count; i++) {
        if (cache->entries[i].image.header == header) {
            return (int32_t)i;
        }
    }
    return -1;
}

static void insert_cache_entry(BSG_Mach_Image_Cache *cache,
                               const BSG_Mach_Image_Range *entry) {
    if (cache->count >= BSG_MACH_HEADERS_MAX_CACHE_ENTRIES ||
        find_cached_header(cache, entry->image.header) >= 0) {
        return;
    }

    uint32_t insertionIndex = 0;
    while (insertionIndex < cache->count &&
           cache->entries[insertionIndex].startAddress < entry->startAddress) {
        insertionIndex++;
    }
    for (uint32_t i = cache->count; i > insertionIndex; i--) {
        cache->entries[i] = cache->entries[i - 1];
    }
    cache->entries[insertionIndex] = *entry;
    cache->count++;
}

const BSG_Dyld_Image_Info *bsg_mach_headers_get_images(uint32_t *count) {
    if (count != NULL) {
        *count = 0;
    }
    struct dyld_all_image_infos *allInfo =
        atomic_load_explicit(&g_all_image_infos, memory_order_relaxed);
    if (allInfo == NULL || allInfo->infoArray == NULL) {
        return NULL;
    }
    const struct dyld_image_info *images = allInfo->infoArray;
    if (count != NULL) {
        *count = allInfo->infoArrayCount;
    }
    return images;
}

static const char *dyld_path(void) {
    struct dyld_all_image_infos *allInfo =
        atomic_load_explicit(&g_all_image_infos, memory_order_relaxed);
    // dyldPath was added in version 15 (macOS 10.12 and iOS 10.0).
    return allInfo != NULL && allInfo->version >= 15 &&
                   allInfo->dyldPath != NULL
               ? allInfo->dyldPath
               : "/usr/lib/dyld";
}

bool bsg_mach_headers_image_for_header(const struct mach_header *header,
                                       const char *name,
                                       BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    BSG_Mach_Image_Range entry;
    if (!populate_cache_entry(header, name, &entry)) {
        return false;
    }
    *image = entry.image;
    return true;
}

static bool cached_image_for_header(const struct mach_header *header,
                                    BSG_Mach_Header_Info *image) {
    BSG_Mach_Image_Cache *cache = atomic_exchange(&g_cache, NULL);
    if (cache == NULL) {
        return false;
    }
    int32_t index = find_cached_header(cache, header);
    if (index >= 0) {
        *image = cache->entries[index].image;
    }
    atomic_store(&g_cache, cache);
    return index >= 0;
}

static bool cached_image_named(const char *imageName,
                               BSG_Mach_Header_Info *image) {
    BSG_Mach_Image_Cache *cache = atomic_exchange(&g_cache, NULL);
    if (cache == NULL) {
        return false;
    }

    bool found = false;
    for (uint32_t i = 0; i < cache->count; i++) {
        const char *cachedName = cache->entries[i].image.name;
        if (cachedName != NULL && strcmp(cachedName, imageName) == 0) {
            if (image != NULL) {
                *image = cache->entries[i].image;
            }
            found = true;
            break;
        }
    }

    atomic_store(&g_cache, cache);
    return found;
}

bool bsg_mach_headers_get_main_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    const struct mach_header *mainHeader = _dyld_get_image_header(0);
    if (mainHeader != NULL && mainHeader->filetype == MH_EXECUTE) {
        if (cached_image_for_header(mainHeader, image)) {
            return true;
        }
        if (bsg_mach_headers_image_for_header(mainHeader,
                                              _dyld_get_image_name(0), image)) {
            return true;
        }
    }

    // Fall back to a filetype search for unusual dyld implementations.
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header != NULL && header->filetype == MH_EXECUTE) {
            if (cached_image_for_header(header, image)) {
                return true;
            }
            return bsg_mach_headers_image_for_header(
                header, images[i].imageFilePath, image);
        }
    }
    return false;
}

bool bsg_mach_headers_get_self_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    const struct mach_header *header = &__dso_handle;
    if (cached_image_for_header(header, image)) {
        return true;
    }

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    for (uint32_t i = 0; i < count; i++) {
        if (images[i].imageLoadAddress == header) {
            return bsg_mach_headers_image_for_header(
                header, images[i].imageFilePath, image);
        }
    }
    return false;
}

bool bsg_mach_headers_get_dyld_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    struct dyld_all_image_infos *allInfo =
        atomic_load_explicit(&g_all_image_infos, memory_order_relaxed);
    if (allInfo == NULL || allInfo->dyldImageLoadAddress == NULL) {
        return false;
    }
    if (cached_image_for_header(allInfo->dyldImageLoadAddress, image)) {
        return true;
    }
    return bsg_mach_headers_image_for_header(allInfo->dyldImageLoadAddress,
                                             dyld_path(), image);
}

bool bsg_mach_headers_image_named(const char *imageName, bool exactMatch,
                                  BSG_Mach_Header_Info *image) {
    if (imageName == NULL) {
        return false;
    }
    // Getters may return a canonical name that differs from dyld's live path
    // for the same image (for example /tmp versus /private/tmp). Honor names
    // already returned by this module before consulting the live image list.
    if (exactMatch && cached_image_named(imageName, image)) {
        return true;
    }
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    for (uint32_t i = 0; i < count; i++) {
        const char *name = images[i].imageFilePath;
        if (name != NULL &&
            ((exactMatch && strcmp(name, imageName) == 0) ||
             (!exactMatch && strstr(name, imageName) != NULL))) {
            return image == NULL ||
                   bsg_mach_headers_image_for_header(images[i].imageLoadAddress,
                                                     name, image);
        }
    }
    const char *name = dyld_path();
    if ((exactMatch && strcmp(name, imageName) == 0) ||
        (!exactMatch && strstr(name, imageName) != NULL)) {
        return image == NULL || bsg_mach_headers_get_dyld_image(image);
    }
    return false;
}

static bool linear_scan_for_address(uintptr_t address,
                                    BSG_Mach_Image_Range *entry) {
    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    for (uint32_t i = 0; i < count; i++) {
        BSG_Mach_Image_Range candidate;
        if (populate_cache_entry(images[i].imageLoadAddress,
                                 images[i].imageFilePath, &candidate) &&
            address_in_segments(&candidate, address)) {
            *entry = candidate;
            return true;
        }
    }

    struct dyld_all_image_infos *allInfo =
        atomic_load_explicit(&g_all_image_infos, memory_order_relaxed);
    BSG_Mach_Image_Range candidate;
    if (allInfo != NULL && allInfo->dyldImageLoadAddress != NULL &&
        populate_cache_entry(allInfo->dyldImageLoadAddress, dyld_path(),
                             &candidate) &&
        address_in_segments(&candidate, address)) {
        *entry = candidate;
        return true;
    }
    return false;
}

bool bsg_mach_headers_image_at_address(uintptr_t address,
                                       BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    BSG_Mach_Image_Cache *cache = atomic_exchange(&g_cache, NULL);
    if (cache != NULL) {
        for (int32_t i = binary_search_cache(cache, address); i >= 0; i--) {
            BSG_Mach_Image_Range *entry = &cache->entries[i];
            if (address >= entry->startAddress && address < entry->endAddress &&
                address_in_segments(entry, address)) {
                *image = entry->image;
                atomic_store(&g_cache, cache);
                return true;
            }
        }

        BSG_Mach_Image_Range entry;
        bool found = linear_scan_for_address(address, &entry);
        if (found) {
            *image = entry.image;
            insert_cache_entry(cache, &entry);
        }
        atomic_store(&g_cache, cache);
        return found;
    }

    BSG_Mach_Image_Range entry;
    if (linear_scan_for_address(address, &entry)) {
        *image = entry.image;
        return true;
    }
    return false;
}

static void image_notifier(enum dyld_image_mode mode, uint32_t infoCount,
                           const struct dyld_image_info info[]) {
    if (mode == dyld_image_adding) {
        BSG_Mach_Image_Cache *cache = atomic_exchange(&g_cache, NULL);
        if (cache != NULL) {
            for (uint32_t i = 0;
                 i < infoCount &&
                 cache->count < BSG_MACH_HEADERS_MAX_CACHE_ENTRIES;
                 i++) {
                BSG_Mach_Image_Range entry;
                if (populate_cache_entry(info[i].imageLoadAddress,
                                         info[i].imageFilePath, &entry)) {
                    insert_cache_entry(cache, &entry);
                }
            }
            atomic_store(&g_cache, cache);
        }
    }

    if (g_original_notifier != NULL) {
        g_original_notifier(mode, infoCount, info);
    }
}

void bsg_mach_headers_initialize(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&g_initialized, &expected, true)) {
        return;
    }

    struct task_dyld_info dyldInfo = {0};
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_DYLD_INFO,
                                     (task_info_t)&dyldInfo, &count);
    if (result != KERN_SUCCESS || dyldInfo.all_image_info_addr == 0) {
        BSG_KSLOG_ERROR("task_info TASK_DYLD_INFO failed: %s",
                        mach_error_string(result));
        return;
    }

    struct dyld_all_image_infos *allInfo = (void *)dyldInfo.all_image_info_addr;
    atomic_store_explicit(&g_all_image_infos, allInfo, memory_order_relaxed);
    g_cache_storage.count = 0;

    const struct mach_header *mainHeader = _dyld_get_image_header(0);
    if (mainHeader != NULL) {
        BSG_Mach_Image_Range entry;
        if (populate_cache_entry(mainHeader, _dyld_get_image_name(0), &entry)) {
            insert_cache_entry(&g_cache_storage, &entry);
        }
    }

    if (allInfo->dyldImageLoadAddress != NULL) {
        BSG_Mach_Image_Range entry;
        if (populate_cache_entry(allInfo->dyldImageLoadAddress, dyld_path(),
                                 &entry)) {
            insert_cache_entry(&g_cache_storage, &entry);
        }
    }

    // Cache Bugsnag itself without replaying callbacks for all loaded images.
    Dl_info selfInfo = {0};
    const struct mach_header *selfHeader = &__dso_handle;
    dladdr(selfHeader, &selfInfo);
    BSG_Mach_Image_Range selfEntry;
    if (populate_cache_entry(selfHeader, selfInfo.dli_fname, &selfEntry)) {
        insert_cache_entry(&g_cache_storage, &selfEntry);
    }

    atomic_store(&g_cache, &g_cache_storage);

    // Unlike _dyld_register_func_for_add_image, installing this notifier does
    // not synchronously replay every image that is already loaded.
    if (allInfo->notification != image_notifier) {
        g_original_notifier = allInfo->notification;
        allInfo->notification = image_notifier;
    }
}

static uintptr_t
bsg_mach_header_info_get_section_addr_named(const BSG_Mach_Header_Info *header,
                                            const char *name) {
    uintptr_t cmdPtr = bsg_mach_headers_first_cmd_after_header(header->header);
    if (!cmdPtr) {
        return 0;
    }
    for (uint32_t i = 0; i < header->header->ncmds; i++) {
        const struct load_command *loadCmd = (void *)cmdPtr;
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command *segment = (void *)cmdPtr;
            char *sectionPtr = (void *)(cmdPtr + sizeof(*segment));
            for (uint32_t j = 0; j < segment->nsects; j++) {
                struct section *section = (void *)sectionPtr;
                if (strcmp(name, section->sectname) == 0) {
                    return section->addr + (uintptr_t)header->slide;
                }
                sectionPtr += sizeof(*section);
            }
        } else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (void *)cmdPtr;
            char *sectionPtr = (void *)(cmdPtr + sizeof(*segment));
            for (uint32_t j = 0; j < segment->nsects; j++) {
                struct section_64 *section = (void *)sectionPtr;
                if (strcmp(name, section->sectname) == 0) {
                    return (uintptr_t)section->addr + (uintptr_t)header->slide;
                }
                sectionPtr += sizeof(*section);
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}

const char *
bsg_mach_headers_get_crash_info_message(const BSG_Mach_Header_Info *header) {
    struct crashreporter_annotations_t info;
    uintptr_t sectionAddress = bsg_mach_header_info_get_section_addr_named(
        header, CRASHREPORTER_ANNOTATIONS_SECTION);
    if (!sectionAddress) {
        return NULL;
    }
    if (bsg_ksmachcopyMem((void *)sectionAddress, &info, sizeof(info)) !=
        KERN_SUCCESS) {
        return NULL;
    }
    if (info.version > CRASHREPORTER_ANNOTATIONS_VERSION || !info.message) {
        return NULL;
    }
    for (uintptr_t i = 0; i < 500; i++) {
        char c;
        if (bsg_ksmachcopyMem((void *)(info.message + i), &c, sizeof(c)) !=
            KERN_SUCCESS) {
            return NULL;
        }
        if (c == '\0') {
            return (const char *)info.message;
        }
    }
    return NULL;
}

void bsg_test_support_mach_headers_reset(void) {
    struct dyld_all_image_infos *allInfo =
        atomic_load_explicit(&g_all_image_infos, memory_order_relaxed);
    if (allInfo != NULL && allInfo->notification == image_notifier) {
        allInfo->notification = g_original_notifier;
    }
    g_original_notifier = NULL;
    atomic_store_explicit(&g_all_image_infos, NULL, memory_order_relaxed);
    atomic_store(&g_cache, NULL);
    g_cache_storage.count = 0;
    atomic_store(&g_initialized, false);
}

uint32_t bsg_test_support_mach_headers_cached_image_count(void) {
    BSG_Mach_Image_Cache *cache = atomic_exchange(&g_cache, NULL);
    if (cache == NULL) {
        return 0;
    }
    uint32_t count = cache->count;
    atomic_store(&g_cache, cache);
    return count;
}
