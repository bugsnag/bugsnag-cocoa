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
#import "BSG_KSCrash.h"
#import "BSG_KSMachHeaders.h"

static NSMutableDictionary<NSString *, NSValue*> *bsg_mach_binary_images_info;
static BSG_Mach_Binary_Images bsg_binary_images;

@interface BSG_KSCrash ()
@end

void initializeBinaryImages(BSG_Mach_Binary_Images *array, size_t initialSize) {
  array->contents = (BSG_Mach_Binary_Image_Info *)malloc(initialSize * sizeof(BSG_Mach_Binary_Image_Info));
  array->used = 0;
  array->size = initialSize;
}

void addBinaryImage(BSG_Mach_Binary_Images *array, BSG_Mach_Binary_Image_Info element) {
  // a->used is the number of used entries, because a->array[a->used++] updates a->used only *after* the array has been accessed.
  // Therefore a->used can go up to a->size
  if (array->used == array->size) {
    array->size *= 2;
    array->contents = (BSG_Mach_Binary_Image_Info *)realloc(array->contents, array->size * sizeof(BSG_Mach_Binary_Image_Info));
  }
  array->contents[array->used++] = element;
}

/**
 * Binary images can only be loaded at most once.  We can use the (file)name as a key, without needing to compare the
 * other fields.  Element order is not important; deletion is accomplished by copying the last item into the deleted
 * position.
 */
bool deleteBinaryImage(BSG_Mach_Binary_Images *array, const char *element_name) {
    for (size_t i=0; i<array->used; i++) {
        BSG_Mach_Binary_Image_Info item = array->contents[i];
        if (strcmp(element_name, item.name) == 0) {
            
            // !!!!!
            array->contents[i] = array->contents[array->used--];
            
            break;
        }
    }
    
    return false;
}

void freeBinaryImages(BSG_Mach_Binary_Images *array) {
  free(array->contents);
  array->contents = NULL;
  array->used = array->size = 0;
}

void bsg_initialise_mach_binary_headers() {
    bsg_mach_binary_images_info = [NSMutableDictionary<NSString *, NSValue*> new];
    initializeBinaryImages(&bsg_binary_images, 100);
}

uintptr_t bsg_ksdlfirstCmdAfterHeader(const struct mach_header *const header);

/**
 * Populate a Mach binary image info structure
 *
 * @param header The Mach binary image header
 *
 * @param info Encapsulated Binary Image info
 *
 * @returns a boolean indicating success
 */
bool populate_info(const struct mach_header *header, BSG_Mach_Binary_Image_Info *info) {
    
    // Early exit conditions; this is not a valid/useful binary image
    // 1. We can't find a sensible Mach command
    uintptr_t cmdPtr = bsg_ksdlfirstCmdAfterHeader(header);
    if (cmdPtr == 0) {
        return false;
    }

    // 2. The image doesn't have a name.  Note: running with a debugger attached causes this condition to match.
    Dl_info DlInfo = (const Dl_info) { 0 };
    dladdr(header, &DlInfo);
    const char *image_name = DlInfo.dli_fname;
    if (!image_name) {
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
    info->mh = header;
    info->cpusubtype = header->cpusubtype;
    info->cputype = header->cputype;
    info->imageSize = imageSize;
    info->imageVmAddr = imageVmAddr;
    info->uuid = uuid;
    info->name = image_name;
    
    return true;
}

/**
 * A callback invoked when dyld loads binary images.  It stores enough relevant info about the
 * image to populate a crash report later.
 *
 * @param header A mach_header structure
 *
 * @param slide The VM offset of the binary image
 */
void bsg_mach_binary_image_added(const struct mach_header *header, intptr_t slide)
{
    BSG_Mach_Binary_Image_Info info = { 0 };
    if (populate_info(header, &info)) {
        NSString *key = [NSString stringWithUTF8String:info.name];
        NSValue *value = [NSValue valueWithBytes:&info
                                        objCType:@encode(BSG_Mach_Binary_Image_Info)];
        
        [bsg_mach_binary_images_info setValue:value forKey:key];
    }
}

/**
 * Called when a binary image is unloaded.
 */
void bsg_mach_binary_image_removed(const struct mach_header *header, intptr_t slide)
{
    // Convert header and slide into an info struct
    BSG_Mach_Binary_Image_Info info;
    if (populate_info(header, &info)) {
        NSString *key = [NSString stringWithUTF8String:info.name];
        [bsg_mach_binary_images_info removeObjectForKey:key];
    }
}

/**
 * Returns a C array of structs describing the loaded Mach binaries
 */
BSG_Mach_Binary_Image_Info* bsg_mach_header_array(size_t *count) {
    @synchronized (@"bsg_mach_header_array") {
    
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
            
            [[[bsg_mach_binary_images_info allValues] objectAtIndex:i] getValue:&info];

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
}

