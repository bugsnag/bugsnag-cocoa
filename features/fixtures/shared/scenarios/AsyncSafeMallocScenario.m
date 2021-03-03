//
//  AsyncSafeMallocScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 22/02/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "Scenario.h"

#include <libkern/OSSpinLockDeprecated.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <malloc/malloc.h>

static void * customMalloc(struct _malloc_zone_t *zone, size_t size) {
    static OSSpinLock spinLock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&spinLock);
    OSSpinLockLock(&spinLock);
    return NULL;
}

static void installCustomMalloc() {
    malloc_zone_t *zone = malloc_default_zone();
    vm_protect(mach_task_self(), (uintptr_t)zone, sizeof(malloc_zone_t), 0, VM_PROT_READ | VM_PROT_WRITE);
    zone->malloc = customMalloc;
    vm_protect(mach_task_self(), (uintptr_t)zone, sizeof(malloc_zone_t), 0, VM_PROT_READ);
}

@interface AsyncSafeMallocScenario : Scenario

@end

@implementation AsyncSafeMallocScenario

- (void)run {
    // Override malloc() with an implementation that will cause a deadlock for any thread that calls malloc()
    installCustomMalloc();
    
    // If the signal handler calls malloc(), the app will hang instead of terminating immediately.
    abort();
}

@end
