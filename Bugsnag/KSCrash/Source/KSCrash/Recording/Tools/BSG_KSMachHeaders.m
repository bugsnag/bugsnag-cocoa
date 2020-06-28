//
//  BSG_KSMachHeaders.m
//  Bugsnag
//
//  Created by Robin Macharg on 04/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import "BSG_KSDynamicLinker.h"
#import "BSG_KSMachHeaders.h"
#import "BugsnagPlatformConditional.h"

// MARK: - Locking

// Pragma's hide unavoidable (and expected) deprecation/unavailable warnings
_Pragma("clang diagnostic push")
_Pragma("clang diagnostic ignored \"-Wunguarded-availability\"")
static os_unfair_lock bsg_mach_binary_images_access_lock_unfair = OS_UNFAIR_LOCK_INIT;
_Pragma("clang diagnostic pop")

_Pragma("clang diagnostic push")
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
static OSSpinLock bsg_mach_binary_images_access_lock_spin = OS_SPINLOCK_INIT;
_Pragma("clang diagnostic pop")

static BOOL bsg_unfair_lock_supported;

// Lock helpers.  These use bulky Pragmas to hide warnings so are in their own functions for clarity.

void bsg_spin_lock() {
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
    OSSpinLockLock(&bsg_mach_binary_images_access_lock_spin);
    _Pragma("clang diagnostic pop")
}

void bsg_spin_unlock() {
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"")
    OSSpinLockUnlock(&bsg_mach_binary_images_access_lock_spin);
    _Pragma("clang diagnostic pop")
}

void bsg_unfair_lock() {
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Wunguarded-availability\"")
    os_unfair_lock_lock(&bsg_mach_binary_images_access_lock_unfair);
    _Pragma("clang diagnostic pop")
}

void bsg_unfair_unlock() {
    _Pragma("clang diagnostic push")
    _Pragma("clang diagnostic ignored \"-Wunguarded-availability\"")
    os_unfair_lock_unlock(&bsg_mach_binary_images_access_lock_unfair);
    _Pragma("clang diagnostic pop")
}

// Lock and unlock sections of code

void bsg_dyld_cache_lock() {
    if (bsg_unfair_lock_supported) {
        bsg_unfair_lock();
    } else {
        bsg_spin_lock();
    }
}

void bsg_dyld_cache_unlock() {
    if (bsg_unfair_lock_supported) {
        bsg_unfair_unlock();
    } else {
        bsg_spin_unlock();
    }
}

BOOL bsg_is_unfair_lock_supported(NSProcessInfo *processInfo) {
    NSOperatingSystemVersion minSdk = {0,0,0};
#if BSG_PLATFORM_IOS
    minSdk.majorVersion = 10;
#elif BSG_PLATFORM_OSX
    minSdk.majorVersion = 10;
    minSdk.minorVersion = 12;
#elif BSG_PLATFORM_TVOS
    minSdk.majorVersion = 10;
#elif BSG_PLATFORM_WATCHOS
    minSdk.majorVersion = 3;
#endif
    return [processInfo isOperatingSystemAtLeastVersion:minSdk];
}

/**
 * MARK: - A Dynamic array container
 * See: https://stackoverflow.com/a/3536261/2431627
 */
typedef struct {
    uint32_t used;
    uint32_t size;
    BSG_Mach_Binary_Image_Info *contents;
} BSG_Mach_Binary_Images;

// MARK: - Replicate the DYLD API

static BSG_Mach_Binary_Images bsg_mach_binary_images;

uint32_t bsg_dyld_image_count(void) {
    return bsg_mach_binary_images.used;
}

BSG_Mach_Binary_Image_Info *bsg_dyld_get_image_info(uint32_t imageIndex) {
    if (imageIndex < bsg_mach_binary_images.used) {
        return &bsg_mach_binary_images.contents[imageIndex];
    }
    return NULL;
}

/**
 * Store a Mach binary image-excapsulating struct in a dynamic array.
 * The array doubles on filling-up.  Typical sizes is expected to be in < 1000 (i.e. 2-3 doublings, at app start-up)
 * This should be called in a threadsafe way; we lock against a simultaneous add and remove.
 */
void bsg_add_mach_binary_image(BSG_Mach_Binary_Image_Info element) {
    
    bsg_dyld_cache_lock();
    
    // Expand array if necessary.  We're slightly paranoid here.  An OOM is likely to be indicative of bigger problems
    // but we should still do *our* best not to crash the app.
    if (bsg_mach_binary_images.used == bsg_mach_binary_images.size) {
        uint32_t newSize = bsg_mach_binary_images.size *= 2;
        uint32_t newAllocationSize = newSize * sizeof(BSG_Mach_Binary_Image_Info);
        errno = 0;
        BSG_Mach_Binary_Image_Info *newAllocation = (BSG_Mach_Binary_Image_Info *)realloc(bsg_mach_binary_images.contents, newAllocationSize);
        
        if (newAllocation != NULL && errno != ENOMEM) {
            bsg_mach_binary_images.size = newSize;
            bsg_mach_binary_images.contents = newAllocation;
        }
        else {
            // Exit early, don't expand the array, don't store the header info and unlock
            bsg_dyld_cache_unlock();
            return;
        }
    }
    
    // Store the value, increment the number of used elements
    bsg_mach_binary_images.contents[bsg_mach_binary_images.used++] = element;
    
    bsg_dyld_cache_unlock();
}

/**
 * Binary images can only be loaded at most once.  We can use the VMAddress as a key, without needing to compare the
 * other fields.  Element order is not important; deletion is accomplished by copying the last item into the deleted
 * position.
 */
void bsg_remove_mach_binary_image(uint64_t imageVmAddr) {
    
    bsg_dyld_cache_lock();
    
    for (uint32_t i=0; i<bsg_mach_binary_images.used; i++) {
        BSG_Mach_Binary_Image_Info item = bsg_mach_binary_images.contents[i];
        
        if (imageVmAddr == item.imageVmAddr) {
            // Note: removal of the last (ith) item involves a redundant copy from last->last.
            if (bsg_mach_binary_images.used >= 2) {
                bsg_mach_binary_images.contents[i] = bsg_mach_binary_images.contents[--bsg_mach_binary_images.used];
            }
            else {
                bsg_mach_binary_images.used = 0;
            }
            break; // an image can only be loaded singularly; exit loop once found
        }
    }
    
    bsg_dyld_cache_unlock();
}

/**
 * Create an empty array with initial capacity to hold Mach header info.
 *
 * @param initialSize The initial array capacity
*/
void bsg_initialise_mach_binary_headers(uint32_t initialSize) {
    bsg_unfair_lock_supported = bsg_is_unfair_lock_supported([NSProcessInfo processInfo]);
    bsg_mach_binary_images.contents = (BSG_Mach_Binary_Image_Info *)malloc(initialSize * sizeof(BSG_Mach_Binary_Image_Info));
    bsg_mach_binary_images.used = 0;
    bsg_mach_binary_images.size = initialSize;
}

/**
 * Populate a Mach binary image info structure
 *
 * @param header The Mach binary image header
 *
 * @param info Encapsulated Binary Image info
 *
 * @returns a boolean indicating success
 */
bool bsg_populate_mach_image_info(const struct mach_header *header, intptr_t slide, BSG_Mach_Binary_Image_Info *info) {
    
    // Early exit conditions; this is not a valid/useful binary image
    // 1. We can't find a sensible Mach command
    uintptr_t cmdPtr = bsg_mach_image_first_cmd_after_header(header);
    if (cmdPtr == 0) {
        return false;
    }

    // 2. The image doesn't have a name.  Note: running with a debugger attached causes this condition to match.
    Dl_info DlInfo = (const Dl_info) { 0 };
    dladdr(header, &DlInfo);
    const char *imageName = DlInfo.dli_fname;
    if (!imageName) {
        return false;
    }
    
    // Look for the TEXT segment to get the image size.
    // Also look for a UUID command.
    uint64_t imageSize = 0;
    uint64_t imageVmAddr = 0;
    uint8_t *uuid = NULL;

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
            struct segment_command_64 *segCmd =
                (struct segment_command_64 *)cmdPtr;
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
        }
        cmdPtr += loadCmd->cmdsize;
    }
    
    // Save these values
    info->header = header;
    info->imageSize = imageSize;
    info->imageVmAddr = imageVmAddr;
    info->uuid = uuid;
    info->name = imageName;
    info->slide = slide;
    
    return true;
}

/**
 * A callback invoked when dyld loads binary images.  It stores enough relevant info about the
 * image to populate a crash report later.
 *
 * @param header A mach_header structure
 *
 * @param slide A virtual memory slide amount. The virtual memory slide amount specifies the difference between the
 *              address at which the image was linked and the address at which the image is loaded.
 */
void bsg_mach_binary_image_added(const struct mach_header *header, intptr_t slide)
{
    BSG_Mach_Binary_Image_Info info = { 0 };
    if (bsg_populate_mach_image_info(header, slide, &info)) {
        bsg_add_mach_binary_image(info);
    }
}

/**
 * Called when a binary image is unloaded.
 */
void bsg_mach_binary_image_removed(const struct mach_header *header, intptr_t slide)
{
    // Convert header into an info struct
    BSG_Mach_Binary_Image_Info info = { 0 };
    if (bsg_populate_mach_image_info(header, slide, &info)) {
        bsg_remove_mach_binary_image(info.imageVmAddr);
    }
}

BSG_Mach_Binary_Image_Info *bsg_mach_image_named(const char *const imageName, bool exactMatch) {
    
    BSG_Mach_Binary_Image_Info *imageFound = NULL;
    
    if (imageName != NULL) {
        for (uint32_t iImg = 0; iImg < bsg_dyld_image_count(); iImg++) {
            BSG_Mach_Binary_Image_Info *img = bsg_dyld_get_image_info(iImg);
            if (img->name == NULL) {
                continue; // name is null if the index is out of range per dyld(3)
            } else if (exactMatch) {
                if (strcmp(img->name, imageName) == 0) {
                    imageFound = img;
                    break;
                }
            } else {
                if (strstr(img->name, imageName) != NULL) {
                    imageFound = img;
                    break;
                }
            }
        }
    }
    
    return imageFound;
}

BSG_Mach_Binary_Image_Info *bsg_mach_image_at_address(const uintptr_t address) {
    
    BSG_Mach_Binary_Image_Info *imageFound = NULL;
    
    for (uint32_t iImg = 0; iImg < bsg_dyld_image_count(); iImg++) {
        BSG_Mach_Binary_Image_Info *img = bsg_dyld_get_image_info(iImg);
        if (img->header != NULL) {
            // Look for a segment command with this address within its range.
            uintptr_t addressWSlide = address - img->slide;
            uintptr_t cmdPtr = bsg_mach_image_first_cmd_after_header(img->header);
            if (cmdPtr == 0) {
                continue;
            }
            for (uint32_t iCmd = 0; iCmd < img->header->ncmds; iCmd++) {
                const struct load_command *loadCmd =
                    (struct load_command *)cmdPtr;
                if (loadCmd->cmd == LC_SEGMENT) {
                    const struct segment_command *segCmd =
                        (struct segment_command *)cmdPtr;
                    if (addressWSlide >= segCmd->vmaddr &&
                        addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        imageFound = img;
                        break;
                    }
                } else if (loadCmd->cmd == LC_SEGMENT_64) {
                    const struct segment_command_64 *segCmd =
                        (struct segment_command_64 *)cmdPtr;
                    if (addressWSlide >= segCmd->vmaddr &&
                        addressWSlide < segCmd->vmaddr + segCmd->vmsize) {
                        imageFound = img;
                        break;
                    }
                }
                cmdPtr += loadCmd->cmdsize;
            }
        }
    }
    
    return imageFound;
}

uintptr_t bsg_mach_image_first_cmd_after_header(const struct mach_header *const header) {
    if (header == NULL) {
      return 0;
    }
    switch (header->magic) {
    case MH_MAGIC:
    case MH_CIGAM:
        return (uintptr_t)(header + 1);
    case MH_MAGIC_64:
    case MH_CIGAM_64:
        return (uintptr_t)(((struct mach_header_64 *)header) + 1);
    default:
        // Header is corrupt
        return 0;
    }
}

uintptr_t bsg_mach_image_base_of_image_index(const struct mach_header *const header) {
    // Look for a segment command and return the file image address.
    uintptr_t cmdPtr = bsg_mach_image_first_cmd_after_header(header);
    if (cmdPtr == 0) {
        return 0;
    }
    for (uint32_t i = 0; i < header->ncmds; i++) {
        const struct load_command *loadCmd = (struct load_command *)cmdPtr;
        if (loadCmd->cmd == LC_SEGMENT) {
            const struct segment_command *segmentCmd =
                (struct segment_command *)cmdPtr;
            if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return segmentCmd->vmaddr - segmentCmd->fileoff;
            }
        } else if (loadCmd->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segmentCmd =
                (struct segment_command_64 *)cmdPtr;
            if (strcmp(segmentCmd->segname, SEG_LINKEDIT) == 0) {
                return (uintptr_t)(segmentCmd->vmaddr - segmentCmd->fileoff);
            }
        }
        cmdPtr += loadCmd->cmdsize;
    }

    return 0;
}
