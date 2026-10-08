//
//  BSG_KSImageMemory.h
//  Bugsnag
//
//  Created by Meiyalagan Ramadurai on 26/09/26.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//
// Bounded, non-allocating reads of memory which dyld may concurrently unmap.
#ifndef BSG_KSImageMemory_h
#define BSG_KSImageMemory_h
#include <mach/mach.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

static inline bool bsg_image_read(const void *source, void *destination, size_t size) {
    if (!source || size > UINTPTR_MAX - (uintptr_t)source) return false;
    vm_size_t copied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)source, size,
                             (vm_address_t)destination, &copied) == KERN_SUCCESS && copied == size;
}

// Never read across a page boundary: the terminating NUL may precede an
// unmapped page. Failure/truncation is explicit, never a borrowed pointer.
static inline bool bsg_image_read_string(const char *source, char *destination, size_t capacity) {
    size_t offset = 0;
    while (source && offset < capacity) {
        uintptr_t address = (uintptr_t)source + offset;
        if (address < (uintptr_t)source) return false;
        size_t size = vm_page_size - address % vm_page_size;
        if (size > capacity - offset) size = capacity - offset;
        if (!bsg_image_read((const void *)address, destination + offset, size)) return false;
        if (memchr(destination + offset, 0, size)) return true;
        offset += size;
    }
    return false;
}
#endif
