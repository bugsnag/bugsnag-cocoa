#ifndef spin_malloc_h
#define spin_malloc_h

#ifdef __cplusplus
extern "C" {
#endif

#include <libkern/OSSpinLockDeprecated.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <malloc/malloc.h>


// Custom malloc implementation that deadlocks the current thread.
static void * spin_malloc(struct _malloc_zone_t *zone, size_t size) {
    static OSSpinLock spinLock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&spinLock);
    OSSpinLockLock(&spinLock);
    return NULL;
}

// Override malloc() with a version that deadlocks the current thread.
static inline void install_spin_malloc() {
    malloc_zone_t *zone = malloc_default_zone();
    vm_protect(mach_task_self(), (uintptr_t)zone, sizeof(malloc_zone_t), 0, VM_PROT_READ | VM_PROT_WRITE);
    zone->malloc = spin_malloc;
    vm_protect(mach_task_self(), (uintptr_t)zone, sizeof(malloc_zone_t), 0, VM_PROT_READ);
}


#ifdef __cplusplus
}
#endif

#endif /* spin_malloc_h */
