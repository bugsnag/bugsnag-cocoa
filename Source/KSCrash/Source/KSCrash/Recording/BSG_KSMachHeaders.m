//
//  BSG_KSMachHeaders.m
//  Bugsnag
//
//  Created by Robin Macharg on 28/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import "BSG_KSCrash.h"
#import "BSG_KSMachHeaders.h"

static NSMutableArray *bsg_mach_binary_images_info;

@interface BSG_KSCrash ()
@end

void bsg_initialise_mach_binary_headers() {
    bsg_mach_binary_images_info = [NSMutableArray new];
}

uintptr_t bsg_ksdlfirstCmdAfterHeader(const struct mach_header *const header);

/**
 * Populate a Mach binary image info structure
 *
 * @param header The Mach binary image header
 *
 * @param slide The VM offset of the binary image
 *
 * @param info A reference to the structure
 *
 * @returns a boolean indicating success
 */
bool populate_info(const struct mach_header *header, intptr_t slide, BSG_Mach_Binary_Image_Info *info) {
    
    // Early exit conditions; this is not a valid/useful binary image
    // 1. We can't find a sensible Mach command
    uintptr_t cmdPtr = bsg_ksdlfirstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return false;
    }

    // 2. The image doesn't have a name.  Note: running with a debugger attached causes this condition to match.
    Dl_info DlInfo = (const Dl_info) { 0 };
    dladdr((const void*)slide, &DlInfo);
    const char *image_name = DlInfo.dli_fname;
    if (!image_name) {
        return false;
    }
    
    info->name = image_name;
    
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
    info->mh = header;
    info->cpusubtype = header->cpusubtype;
    info->cputype = header->cputype;
    info->imageSize = imageSize;
    info->imageVmAddr = imageVmAddr;
    info->uuid = uuid;
    
    return true;
}

/**
 * A callback invoked when dyld loads binary images.  It stores enough relevant info about the
 * image to populate a crash report later.
 *
 * @param header A mach_header structure
 * @param slide The VM offset of the binary image
 */
void bsg_mach_binary_image_added(const struct mach_header *header, intptr_t slide)
{
    BSG_Mach_Binary_Image_Info info;
    if (populate_info(header, slide, &info)) {
        [bsg_mach_binary_images_info addObject:[NSValue valueWithBytes:&info
                                                          objCType:@encode(BSG_Mach_Binary_Image_Info)]];
    }
}

/**
 * Compare two mach biunary image structures
 */
bool infos_are_equal(BSG_Mach_Binary_Image_Info *info1, BSG_Mach_Binary_Image_Info *info2) {
    return info1->cpusubtype == info2->cpusubtype &&
        info1->cputype == info2->cputype &&
        info1->imageSize == info2->imageSize &&
        info1->imageVmAddr == info2->imageVmAddr &&
        info1->name == info2->name &&
        info1->uuid == info2->uuid &&
        info1->mh->filetype == info2->mh->filetype &&
        info1->mh->flags == info2->mh->flags &&
        info1->mh->magic == info2->mh->magic &&
        info1->mh->ncmds == info2->mh->ncmds &&
        info1->mh->sizeofcmds == info2->mh->sizeofcmds;
}

/**
 * Called when a binary image is unloaded.
 */
void bsg_mach_binary_image_removed(const struct mach_header *header, intptr_t slide)
{
    // Convert header and slide into an info struct
    BSG_Mach_Binary_Image_Info info;
    if (populate_info(header, slide, &info)) {
        
        // We need to search the array manually.  This should be an infrequent operation.
        for (int i=0;i<[bsg_mach_binary_images_info count];++i) {
            
            // Reconstitute the struct from the stored NSValue
            BSG_Mach_Binary_Image_Info array_info;
            [[bsg_mach_binary_images_info objectAtIndex:i] getValue:&array_info];
            
            // Remove it if it's been found.  Can't have a binary imag eloaded more than once, so safe to break.
            if (infos_are_equal(&array_info, &info)) {
                [bsg_mach_binary_images_info removeObjectAtIndex:i];
                break;
            }
        }
    }
}

/**
 * Returns a C array of structs describing the loaded Mach binaries
 */
BSG_Mach_Binary_Image_Info* bsg_mach_header_array(size_t *count) {
    // Pass out the number of binary images
    *count = [bsg_mach_binary_images_info count] ;
    
    // How big is our struct?
    const size_t mach_header_size = sizeof(BSG_Mach_Binary_Image_Info);
    
    // Heap allocate the array of binary image info structs
    BSG_Mach_Binary_Image_Info *headers = (BSG_Mach_Binary_Image_Info *)calloc(*count, mach_header_size);
    
    // Copy the info into an array
    for (size_t i=0; i<*count; ++i) {
        
        // Reconstitute struct from NSValue
        BSG_Mach_Binary_Image_Info info;
        [[bsg_mach_binary_images_info objectAtIndex:i] getValue:&info];

        headers[i].cpusubtype = info.cpusubtype;
        headers[i].cputype = info.cputype;
        headers[i].imageSize = info.imageSize;
        headers[i].imageVmAddr = info.imageVmAddr;
        headers[i].uuid = info.uuid;
        headers[i].mh = info.mh;
        headers[i].name = info.name;
    }
    
    return headers;
}
