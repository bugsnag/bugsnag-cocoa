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
static _Atomic(bool) is_mach_headers_initialized;

static intptr_t compute_slide(const struct mach_header *header);
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

void bsg_mach_headers_initialize(void) {
    bool expected = false;
    if (!atomic_compare_exchange_strong(&is_mach_headers_initialized,
                                        &expected, true)) {
        return;
    }

    register_dyld_images();

    if (!g_all_image_infos) {
        atomic_store(&is_mach_headers_initialized, false);
    }
}

const BSG_Dyld_Image_Info *bsg_mach_headers_get_images(uint32_t *count) {
    bsg_mach_headers_initialize();

    if (!g_all_image_infos) {
        if (count != NULL) {
            *count = 0;
        }
        return NULL;
    }

    if (count != NULL) {
        *count = g_all_image_infos->infoArrayCount;
    }
    return g_all_image_infos->infoArray;
}

bool bsg_mach_headers_get_main_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    bsg_mach_headers_initialize();

    if (g_main_image != NULL) {
        return copy_cached_image(g_main_image, image);
    }

    uint32_t count = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&count);
    if (images == NULL) {
        return false;
    }

    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header != NULL && header->filetype == MH_EXECUTE) {
            return cache_image_for_header(header, images[i].imageFilePath,
                                          NULL) &&
                   populate_image_info(header, compute_slide(header),
                                       images[i].imageFilePath, image);
        }
    }
    return false;
}

bool bsg_mach_headers_get_self_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    bsg_mach_headers_initialize();

    if (g_self_image != NULL) {
        return copy_cached_image(g_self_image, image);
    }

    return cache_image_for_header((const struct mach_header *)&__dso_handle,
                                  NULL, NULL) &&
           populate_image_info((const struct mach_header *)&__dso_handle,
                               compute_slide((const struct mach_header *)&__dso_handle),
                               NULL, image);
}

bool bsg_mach_headers_get_dyld_image(BSG_Mach_Header_Info *image) {
    if (image == NULL) {
        return false;
    }
    bsg_mach_headers_initialize();

    if (g_dyld_image != NULL) {
        return copy_cached_image(g_dyld_image, image);
    }

    if (g_all_image_infos == NULL || g_all_image_infos->dyldImageLoadAddress == NULL) {
        return false;
    }

    return populate_image_info(g_all_image_infos->dyldImageLoadAddress,
                               compute_slide(g_all_image_infos->dyldImageLoadAddress),
                               g_all_image_infos->dyldPath, image);
}

bool bsg_mach_headers_image_for_header(const struct mach_header *header,
                                       const char *name,
                                       BSG_Mach_Header_Info *image) {
    if (header == NULL || image == NULL) {
        return false;
    }
    bsg_mach_headers_initialize();
    return populate_image_info(header, compute_slide(header), name, image);
}

bool bsg_mach_headers_image_at_address(uintptr_t address,
                                       BSG_Mach_Header_Info *image) {
    if (image == NULL || address == 0) {
        return false;
    }
    bsg_mach_headers_initialize();

    BSG_Mach_Image_Node *cached = find_cached_image_at_address(address);
    if (cached != NULL) {
        return copy_cached_image(cached, image);
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

    for (uint32_t i = 0; i < count; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header == NULL) {
            continue;
        }
        if (populate_image_info(header, compute_slide(header),
                                images[i].imageFilePath, image) &&
            image_contains_address(image, address)) {
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
    bsg_mach_headers_initialize();

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
        const char *candidateName = images[i].imageFilePath;
        if (candidateName == NULL) {
            continue;
        }

        bool matches = exactMatch ? strcmp(candidateName, imageName) == 0
                                  : strstr(candidateName, imageName) != NULL;
        if (!matches) {
            continue;
        }

        const struct mach_header *header = images[i].imageLoadAddress;
        if (header != NULL) {
            if (image == NULL) {
                return true;
            }
            if (populate_image_info(header, compute_slide(header),
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

static uintptr_t bsg_mach_header_info_get_section_addr_named(const BSG_Mach_Header_Info *header,
                                                             const char *name) {
    uintptr_t cmdPtr = bsg_mach_headers_first_cmd_after_header(header->header);
    if (!cmdPtr) {
        return 0;
    }

    for (uint32_t i = 0; i < header->header->ncmds; i++) {
        const struct load_command *loadCmd = (const struct load_command *)cmdPtr;
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command *segment = (const void *)cmdPtr;
            char *sectionPtr = (void *)(cmdPtr + sizeof(*segment));
            for (uint32_t j = 0; j < segment->nsects; j++) {
                struct section *section = (void *)sectionPtr;
                if (strcmp(name, section->sectname) == 0) {
                    return section->addr + (uintptr_t)header->slide;
                }
                sectionPtr += sizeof(*section);
            }
        } else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment = (const void *)cmdPtr;
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

const char *bsg_mach_headers_get_crash_info_message(const BSG_Mach_Header_Info *header) {
    struct crashreporter_annotations_t info;
    uintptr_t sectionAddress =
        bsg_mach_header_info_get_section_addr_named(header, CRASHREPORTER_ANNOTATIONS_SECTION);
    if (!sectionAddress) {
        return NULL;
    }
    if (bsg_ksmachcopyMem((void *)sectionAddress, &info, sizeof(info)) != KERN_SUCCESS) {
        return NULL;
    }
    if (info.version > CRASHREPORTER_ANNOTATIONS_VERSION) {
        return NULL;
    }
    if (!info.message) {
        return NULL;
    }

    for (uintptr_t i = 0; i < 500; i++) {
        char c;
        if (bsg_ksmachcopyMem((void *)(info.message + i), &c, sizeof(c)) != KERN_SUCCESS) {
            return NULL;
        }
        if (c == '\0') {
            return (const char *)info.message;
        }
    }
    return NULL;
}

void bsg_test_support_mach_headers_reset(void) {
    clear_cached_images();
    g_all_image_infos = NULL;
    atomic_store(&is_mach_headers_initialized, false);
}

uint32_t bsg_test_support_mach_headers_cached_image_count(void) {
    return atomic_load(&g_cached_image_count);
}

bool bsg_mach_headers_populate_info(const struct mach_header *header,
                                    intptr_t slide,
                                    BSG_Mach_Header_Info *info) {
    return populate_image_info(header, slide, NULL, info);
}

void bsg_test_support_mach_headers_add_image(const struct mach_header *header,
                                             intptr_t slide) {
    BSG_Mach_Header_Info info;
    if (populate_image_info(header, slide, NULL, &info)) {
        cache_image(&info, NULL);
    }
}

void bsg_test_support_mach_headers_remove_image(const struct mach_header *header,
                                                intptr_t slide) {
    if (header == NULL) {
        return;
    }

    BSG_Mach_Header_Info expected;
    if (!populate_image_info(header, slide, NULL, &expected)) {
        return;
    }

    BSG_Mach_Image_Node **link = &g_cached_images_head;
    while (*link != NULL) {
        BSG_Mach_Image_Node *node = *link;
        if (node->info.header == expected.header &&
            node->info.imageVmAddr == expected.imageVmAddr) {
            *link = node->next;
            if (g_cached_images_tail == node) {
                g_cached_images_tail = NULL;
                for (BSG_Mach_Image_Node *scan = g_cached_images_head; scan != NULL;
                     scan = scan->next) {
                    g_cached_images_tail = scan;
                }
            }
            if (g_main_image == node) {
                g_main_image = NULL;
            }
            if (g_self_image == node) {
                g_self_image = NULL;
            }
            if (g_dyld_image == node) {
                g_dyld_image = NULL;
            }
            free(node);
            atomic_fetch_sub(&g_cached_image_count, 1);
            return;
        }
        link = &node->next;
    }
}

static void register_dyld_images(void) {
    task_dyld_info_data_t dyld_info = {0};
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t result = task_info(mach_task_self(), TASK_DYLD_INFO,
                                     (task_info_t)&dyld_info, &count);
    if (result != KERN_SUCCESS || dyld_info.all_image_info_addr == 0) {
        BSG_KSLOG_ERROR("task_info TASK_DYLD_INFO failed: %s",
                        mach_error_string(result));
        atomic_store(&is_mach_headers_initialized, false);
        return;
    }

    g_all_image_infos = (const void *)dyld_info.all_image_info_addr;

    if (g_all_image_infos->dyldImageLoadAddress != NULL) {
        cache_image_for_header(g_all_image_infos->dyldImageLoadAddress,
                               g_all_image_infos->dyldPath, &g_dyld_image);
    }

    const struct mach_header *mainHeader = NULL;
    uint32_t imageCount = 0;
    const BSG_Dyld_Image_Info *images = bsg_mach_headers_get_images(&imageCount);
    for (uint32_t i = 0; images != NULL && i < imageCount; i++) {
        const struct mach_header *header = images[i].imageLoadAddress;
        if (header != NULL && header->filetype == MH_EXECUTE) {
            mainHeader = header;
            cache_image_for_header(header, images[i].imageFilePath, &g_main_image);
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

static bool populate_image_info(const struct mach_header *header, intptr_t slide,
                                const char *name,
                                BSG_Mach_Header_Info *info) {
    if (header == NULL || info == NULL) {
        return false;
    }

    uintptr_t cmdPtr = bsg_mach_headers_first_cmd_after_header(header);
    if (cmdPtr == 0) {
        BSG_KSLOG_ERROR("Invalid mach header @ %p", header);
        return false;
    }

    const char *imageName = name != NULL ? name : get_path(header);
    if (imageName == NULL) {
        BSG_KSLOG_ERROR("Could not find name for mach header @ %p", header);
        return false;
    }

    uint64_t imageSize = 0;
    uint64_t imageVmAddr = 0;
    const uint8_t *uuid = NULL;

    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        struct load_command *loadCmd = (struct load_command *)cmdPtr;
        switch (loadCmd->cmd) {
            case LC_SEGMENT: {
                struct segment_command *segCmd = (struct segment_command *)cmdPtr;
                if (strcmp(segCmd->segname, SEG_TEXT) == 0) {
                    imageSize = segCmd->vmsize;
                    imageVmAddr = segCmd->vmaddr;
                }
                break;
            }
            case LC_SEGMENT_64: {
                struct segment_command_64 *segCmd = (struct segment_command_64 *)cmdPtr;
                if (strcmp(segCmd->segname, SEG_TEXT) == 0) {
                    imageSize = segCmd->vmsize;
                    imageVmAddr = segCmd->vmaddr;
                }
                break;
            }
            case LC_UUID: {
                struct uuid_command *uuidCmd = (struct uuid_command *)cmdPtr;
                uuid = uuidCmd->uuid;
                break;
            }
            default:
                break;
        }
        cmdPtr += loadCmd->cmdsize;
    }

    if (imageVmAddr != 0 && ((uintptr_t)imageVmAddr + (uintptr_t)slide) != (uintptr_t)header) {
        BSG_KSLOG_ERROR("Mach header != (vmaddr + slide) for %s; symbolication will be compromised.",
                        imageName);
    }

    info->header = header;
    info->imageVmAddr = imageVmAddr;
    info->imageSize = imageSize;
    info->uuid = uuid;
    info->name = imageName;
    info->slide = slide;
    return true;
}

static bool image_contains_address(const BSG_Mach_Header_Info *image,
                                   uintptr_t address) {
    if (image == NULL || image->header == NULL || image->imageSize == 0) {
        return false;
    }
    uintptr_t imageStart = (uintptr_t)image->header;
    return address >= imageStart && address < (imageStart + image->imageSize);
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
    *image = node->info;
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
            node->info = *image;
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

    node->info = *image;
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
    if (!populate_image_info(header, compute_slide(header), name, &image)) {
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

static intptr_t compute_slide(const struct mach_header *header) {
    uintptr_t cmdPtr = bsg_mach_headers_first_cmd_after_header(header);
    if (!cmdPtr) {
        return 0;
    }

    for (uint32_t iCmd = 0; iCmd < header->ncmds; iCmd++) {
        struct load_command *loadCmd = (void *)cmdPtr;
        switch (loadCmd->cmd) {
            case LC_SEGMENT: {
                struct segment_command *segCmd = (void *)cmdPtr;
                if (strcmp(segCmd->segname, SEG_TEXT) == 0) {
                    return (intptr_t)header - (intptr_t)segCmd->vmaddr;
                }
            }
            case LC_SEGMENT_64: {
                struct segment_command_64 *segCmd = (void *)cmdPtr;
                if (strcmp(segCmd->segname, SEG_TEXT) == 0) {
                    return (intptr_t)header - (intptr_t)segCmd->vmaddr;
                }
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }
    return 0;
}

static const char *get_path(const struct mach_header *header) {
    Dl_info dlInfo = {0};
    dladdr(header, &dlInfo);
    if (dlInfo.dli_fname != NULL) {
        return dlInfo.dli_fname;
    }

    if (g_all_image_infos != NULL &&
        header == g_all_image_infos->dyldImageLoadAddress) {
        return g_all_image_infos->dyldPath;
    }

#if TARGET_OS_SIMULATOR
    if (g_all_image_infos != NULL && g_all_image_infos->infoArray != NULL &&
        g_all_image_infos->infoArray[0].imageLoadAddress == header) {
        return g_all_image_infos->infoArray[0].imageFilePath;
    }
#endif

    return NULL;
}
