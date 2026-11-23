//
//  KSMach.c
//
//  Created by Karl Stenerud on 2012-01-29.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "BSG_KSMach.h"

#include "BSG_KSMachApple.h"
#include "BSGDefines.h"

//#define BSG_KSLogger_LocalLevel TRACE
#include "BSG_KSLogger.h"

#include <errno.h>
#include <mach-o/arch.h>
#include <mach/mach_time.h>
#include <sys/sysctl.h>

// Avoiding static functions due to linker issues.

// ============================================================================
#pragma mark - General Information -
// ============================================================================

#define RETURN_NAME_FOR_ENUM(A)                                                \
    case A:                                                                    \
        return #A

const char *bsg_ksmachexceptionName(const exception_type_t exceptionType) {
    switch (exceptionType) {
        RETURN_NAME_FOR_ENUM(EXC_BAD_ACCESS);
        RETURN_NAME_FOR_ENUM(EXC_BAD_INSTRUCTION);
        RETURN_NAME_FOR_ENUM(EXC_ARITHMETIC);
        RETURN_NAME_FOR_ENUM(EXC_EMULATION);
        RETURN_NAME_FOR_ENUM(EXC_SOFTWARE);
        RETURN_NAME_FOR_ENUM(EXC_BREAKPOINT);
        RETURN_NAME_FOR_ENUM(EXC_SYSCALL);
        RETURN_NAME_FOR_ENUM(EXC_MACH_SYSCALL);
        RETURN_NAME_FOR_ENUM(EXC_RPC_ALERT);
        RETURN_NAME_FOR_ENUM(EXC_CRASH);
#ifdef EXC_GUARD
        RETURN_NAME_FOR_ENUM(EXC_GUARD);
#endif
    }
    return NULL;
}

// ============================================================================
#pragma mark - EXC_GUARD -
// ============================================================================

// Keep the mirrored values in sync with the SDK wherever the SDK defines them.
#ifdef GUARD_TYPE_MACH_PORT
_Static_assert(GUARD_TYPE_MACH_PORT == BSG_GUARD_TYPE_MACH_PORT,
               "GUARD_TYPE_MACH_PORT mismatch");
#endif
#ifdef GUARD_TYPE_FD
_Static_assert(GUARD_TYPE_FD == BSG_GUARD_TYPE_FD, "GUARD_TYPE_FD mismatch");
#endif
#ifdef GUARD_TYPE_USER
_Static_assert(GUARD_TYPE_USER == BSG_GUARD_TYPE_USER,
               "GUARD_TYPE_USER mismatch");
#endif
#ifdef GUARD_TYPE_VN
_Static_assert(GUARD_TYPE_VN == BSG_GUARD_TYPE_VN, "GUARD_TYPE_VN mismatch");
#endif
#ifdef GUARD_TYPE_VIRT_MEMORY
_Static_assert(GUARD_TYPE_VIRT_MEMORY == BSG_GUARD_TYPE_VIRT_MEMORY,
               "GUARD_TYPE_VIRT_MEMORY mismatch");
#endif
#ifdef GUARD_TYPE_REJECTED_SC
_Static_assert(GUARD_TYPE_REJECTED_SC == BSG_GUARD_TYPE_REJECTED_SC,
               "GUARD_TYPE_REJECTED_SC mismatch");
#endif

// Mach port guard reasons up to and including this value are always fatal
// (<mach/port.h>; kGUARD_EXC_MSG_FILTERED, unchanged since xnu-7195 / iOS 14).
#define BSG_MAX_FATAL_kGUARD_EXC_CODE 0x80
#ifdef MAX_FATAL_kGUARD_EXC_CODE
_Static_assert(MAX_FATAL_kGUARD_EXC_CODE == BSG_MAX_FATAL_kGUARD_EXC_CODE,
               "MAX_FATAL_kGUARD_EXC_CODE mismatch");
#endif

// The only non-fatal vnode guard flavor (XNU bsd/sys/guarded.h).
#define BSG_VNG_PERMISSIONS (1u << 7)

// Mach port guard reasons above BSG_MAX_FATAL_kGUARD_EXC_CODE and up to and
// including this value ("optional" guards) are fatal only if the task's guard
// behavior has TASK_EXC_GUARD_MP_FATAL (<mach/port.h>; kGUARD_EXC_RCV_INVALID_NAME).
#define BSG_MAX_OPTIONAL_kGUARD_EXC_CODE (1u << 19)
#ifdef MAX_OPTIONAL_kGUARD_EXC_CODE
_Static_assert(MAX_OPTIONAL_kGUARD_EXC_CODE == BSG_MAX_OPTIONAL_kGUARD_EXC_CODE,
               "MAX_OPTIONAL_kGUARD_EXC_CODE mismatch");
#endif

// Task guard behavior bits (<mach/task_info.h>). Optional Mach port guards and
// virtual memory guards are fatal only if the task has the FATAL bit set.
#define BSG_TASK_EXC_GUARD_VM_FATAL 0x08
#define BSG_TASK_EXC_GUARD_MP_FATAL 0x80
#ifdef TASK_EXC_GUARD_VM_FATAL
_Static_assert(TASK_EXC_GUARD_VM_FATAL == BSG_TASK_EXC_GUARD_VM_FATAL, "TASK_EXC_GUARD_VM_FATAL mismatch");
#endif
#ifdef TASK_EXC_GUARD_MP_FATAL
_Static_assert(TASK_EXC_GUARD_MP_FATAL == BSG_TASK_EXC_GUARD_MP_FATAL, "TASK_EXC_GUARD_MP_FATAL mismatch");
#endif

const char *bsg_ksmachguardTypeName(const uint64_t guardType) {
    switch (guardType) {
    case BSG_GUARD_TYPE_NONE:
        return "GUARD_TYPE_NONE";
    case BSG_GUARD_TYPE_MACH_PORT:
        return "GUARD_TYPE_MACH_PORT";
    case BSG_GUARD_TYPE_FD:
        return "GUARD_TYPE_FD";
    case BSG_GUARD_TYPE_USER:
        return "GUARD_TYPE_USER";
    case BSG_GUARD_TYPE_VN:
        return "GUARD_TYPE_VN";
    case BSG_GUARD_TYPE_VIRT_MEMORY:
        return "GUARD_TYPE_VIRT_MEMORY";
    case BSG_GUARD_TYPE_REJECTED_SC:
        return "GUARD_TYPE_REJECTED_SC";
    }
    return NULL;
}

// Always-fatal Mach port guard reasons (enum mach_port_guard_exception_codes
// in <mach/port.h>). Only these can be recorded, so only these are named.
static const char *bsg_ksmachguardMachPortFlavorName(const uint64_t flavor) {
    switch (flavor) {
    case 1: return "kGUARD_EXC_DESTROY";
    case 2: return "kGUARD_EXC_MOD_REFS";
    case 3: return "kGUARD_EXC_INVALID_OPTIONS";
    case 4: return "kGUARD_EXC_SET_CONTEXT";
    case 5: return "kGUARD_EXC_THREAD_SET_STATE";
    case 6: return "kGUARD_EXC_EXCEPTION_BEHAVIOR_ENFORCE";
    case 7: return "kGUARD_EXC_SERVICE_PORT_VIOLATION_FATAL";
    case 8: return "kGUARD_EXC_UNGUARDED";
    case 9: return "kGUARD_EXC_KOBJECT_REPLY_PORT_SEMANTICS";
    case 10: return "kGUARD_EXC_REQUIRE_REPLY_PORT_SEMANTICS";
    case 11: return "kGUARD_EXC_RESTRICT_VOUCHER_OPERATIONS";
    case 12: return "kGUARD_EXC_MACH_EXC_THREAD_SET_STATE";
    case 13: return "kGUARD_EXC_MOVE_WEAK_REPLY_PORT_FATAL";
    case 16: return "kGUARD_EXC_INCORRECT_GUARD";
    case 17: return "kGUARD_EXC_BOOTSTRAP_PORT_NOTIFICATION";
    case 18: return "kGUARD_EXC_CV_INVALID_EXCEPTION_PORT";
    case 32: return "kGUARD_EXC_IMMOVABLE";
    case 33: return "kGUARD_EXC_RESTRICT_VOUCHER_RECIPE_SIZE";
    case 34: return "kGUARD_EXC_RESTRICT_INLINE_PORT_DESCRIPTORS";
    case 64: return "kGUARD_EXC_STRICT_REPLY";
    case 65: return "kGUARD_EXC_INVALID_NOTIFICATION_REQ";
    case 66: return "kGUARD_EXC_INVALID_MPO_ENTITLEMENT";
    case 67: return "kGUARD_EXC_DESCRIPTOR_VIOLATION";
    case 128: return "kGUARD_EXC_MSG_FILTERED";
    // "Optional" reasons: fatal only if the task has TASK_EXC_GUARD_MP_FATAL.
    case 1u << 8: return "kGUARD_EXC_INVALID_RIGHT";
    case 1u << 9: return "kGUARD_EXC_INVALID_NAME";
    case 1u << 10: return "kGUARD_EXC_INVALID_VALUE";
    case 1u << 11: return "kGUARD_EXC_INVALID_ARGUMENT";
    case 1u << 12: return "kGUARD_EXC_RIGHT_EXISTS";
    case 1u << 13: return "kGUARD_EXC_KERN_NO_SPACE";
    case 1u << 14: return "kGUARD_EXC_KERN_FAILURE";
    case 1u << 15: return "kGUARD_EXC_KERN_RESOURCE";
    case 1u << 16: return "kGUARD_EXC_SEND_INVALID_REPLY";
    case 1u << 17: return "kGUARD_EXC_SEND_INVALID_VOUCHER";
    case 1u << 18: return "kGUARD_EXC_SEND_INVALID_RIGHT";
    case 1u << 19: return "kGUARD_EXC_RCV_INVALID_NAME";
    }
    return NULL;
}

// XNU osfmk/mach/vm_statistics.h (virtual_memory_guard_exception_code_t).
static const char *bsg_ksmachguardVirtualMemoryFlavorName(const uint64_t flavor) {
    switch (flavor) {
    case 1: return "kGUARD_EXC_DEALLOC_GAP";
    case 2: return "kGUARD_EXC_RECLAIM_COPYIO_FAILURE";
    case 4: return "kGUARD_EXC_RECLAIM_INDEX_FAILURE";
    case 8: return "kGUARD_EXC_RECLAIM_DEALLOCATE_FAILURE";
    case 9: return "kGUARD_EXC_RECLAIM_ACCOUNTING_FAILURE";
    case 10: return "kGUARD_EXC_SEC_IOPL_ON_EXEC_PAGE";
    case 11: return "kGUARD_EXC_SEC_EXEC_ON_IOPL_PAGE";
    case 12: return "kGUARD_EXC_SEC_UPL_WRITE_ON_EXEC_REGION";
    case 98: return "kGUARD_EXC_SEC_ACCESS_FAULT";
    case 99: return "kGUARD_EXC_SEC_ASYNC_ACCESS_FAULT";
    case 100: return "kGUARD_EXC_SEC_COPY_DENIED";
    case 101: return "kGUARD_EXC_SEC_SHARING_DENIED";
    }
    return NULL;
}

// File descriptor guard flavors (enum guard_fd_exception_codes in XNU
// bsd/sys/guarded.h, which is not part of the public SDKs).
static const char *bsg_ksmachguardFDFlavorName(const uint64_t flavor) {
    switch (flavor) {
    case 1u << 0: return "kGUARD_EXC_CLOSE";
    case 1u << 1: return "kGUARD_EXC_DUP";
    case 1u << 2: return "kGUARD_EXC_NOCLOEXEC";
    case 1u << 3: return "kGUARD_EXC_SOCKET_IPC";
    case 1u << 4: return "kGUARD_EXC_FILEPORT";
    case 1u << 5: return "kGUARD_EXC_MISMATCH";
    case 1u << 6: return "kGUARD_EXC_WRITE";
    }
    return NULL;
}

const char *bsg_ksmachguardFlavorName(const uint64_t guardType,
                                      const uint64_t flavor) {
    switch (guardType) {
    case BSG_GUARD_TYPE_MACH_PORT:
        return bsg_ksmachguardMachPortFlavorName(flavor);
    case BSG_GUARD_TYPE_FD:
        return bsg_ksmachguardFDFlavorName(flavor);
    case BSG_GUARD_TYPE_VIRT_MEMORY:
        return bsg_ksmachguardVirtualMemoryFlavorName(flavor);
    }
    return NULL;
}

bool bsg_ksmachguardIsFatalWithPolicy(const int64_t code, const uint32_t taskGuardBehavior) {
    const uint64_t flavor = BSG_EXC_GUARD_DECODE_GUARD_FLAVOR(code);
    switch (BSG_EXC_GUARD_DECODE_GUARD_TYPE(code)) {
    case BSG_GUARD_TYPE_FD:
        // fd_guard_ast() exits the process after delivery for every flavor.
        return true;
    case BSG_GUARD_TYPE_MACH_PORT:
        // mach_port_guard_exception() is fatal for reasons up to
        // MAX_FATAL_kGUARD_EXC_CODE. Reasons up to MAX_OPTIONAL_kGUARD_EXC_CODE
        // are fatal only if the task has TASK_EXC_GUARD_MP_FATAL. Higher
        // ("soft") reasons can be delivered while the process keeps running.
        if (flavor != 0 && flavor <= BSG_MAX_FATAL_kGUARD_EXC_CODE) {
            return true;
        }
        return flavor > BSG_MAX_FATAL_kGUARD_EXC_CODE && flavor <= BSG_MAX_OPTIONAL_kGUARD_EXC_CODE &&
               (taskGuardBehavior & BSG_TASK_EXC_GUARD_MP_FATAL) != 0;
    case BSG_GUARD_TYPE_VN:
        // vn_guard_ast() exits the process for every flavor except
        // VNG_PERMISSIONS.
        return flavor != 0 && flavor != BSG_VNG_PERMISSIONS;
    case BSG_GUARD_TYPE_VIRT_MEMORY:
        // virt_memory_guard_ast() exits the process after delivery only if the
        // task has TASK_EXC_GUARD_VM_FATAL, whatever the flavor.
        return (taskGuardBehavior & BSG_TASK_EXC_GUARD_VM_FATAL) != 0;
    default:
        // GUARD_TYPE_USER: raised as a simulated crash, not a sync delivery.
        // GUARD_TYPE_REJECTED_SC and unknown types: not determinable.
        return false;
    }
}

// task_get_exc_guard_behavior() is not available on every OS version the SDK
// supports, so it is weakly linked and checked before use.
extern kern_return_t task_get_exc_guard_behavior(task_inspect_t task, task_exc_guard_behavior_t *behaviorp)
    __attribute__((weak_import));

bool bsg_ksmachguardIsFatal(const int64_t code) {
    uint32_t behavior = 0;
    const uint64_t type = BSG_EXC_GUARD_DECODE_GUARD_TYPE(code);
    // Only the types whose fatality depends on the task's guard behavior need it.
    if (type == BSG_GUARD_TYPE_VIRT_MEMORY || type == BSG_GUARD_TYPE_MACH_PORT) {
        if (task_get_exc_guard_behavior != NULL) {
            task_exc_guard_behavior_t value = 0;
            if (task_get_exc_guard_behavior(mach_task_self(), &value) == KERN_SUCCESS) {
                behavior = (uint32_t)value;
            }
        }
    }
    return bsg_ksmachguardIsFatalWithPolicy(code, behavior);
}

const char *bsg_ksmachkernelReturnCodeName(const kern_return_t returnCode) {
    switch (returnCode) {
        RETURN_NAME_FOR_ENUM(KERN_SUCCESS);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_ADDRESS);
        RETURN_NAME_FOR_ENUM(KERN_PROTECTION_FAILURE);
        RETURN_NAME_FOR_ENUM(KERN_NO_SPACE);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_ARGUMENT);
        RETURN_NAME_FOR_ENUM(KERN_FAILURE);
        RETURN_NAME_FOR_ENUM(KERN_RESOURCE_SHORTAGE);
        RETURN_NAME_FOR_ENUM(KERN_NOT_RECEIVER);
        RETURN_NAME_FOR_ENUM(KERN_NO_ACCESS);
        RETURN_NAME_FOR_ENUM(KERN_MEMORY_FAILURE);
        RETURN_NAME_FOR_ENUM(KERN_MEMORY_ERROR);
        RETURN_NAME_FOR_ENUM(KERN_ALREADY_IN_SET);
        RETURN_NAME_FOR_ENUM(KERN_NOT_IN_SET);
        RETURN_NAME_FOR_ENUM(KERN_NAME_EXISTS);
        RETURN_NAME_FOR_ENUM(KERN_ABORTED);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_NAME);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_TASK);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_RIGHT);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_VALUE);
        RETURN_NAME_FOR_ENUM(KERN_UREFS_OVERFLOW);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_CAPABILITY);
        RETURN_NAME_FOR_ENUM(KERN_RIGHT_EXISTS);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_HOST);
        RETURN_NAME_FOR_ENUM(KERN_MEMORY_PRESENT);
        RETURN_NAME_FOR_ENUM(KERN_MEMORY_DATA_MOVED);
        RETURN_NAME_FOR_ENUM(KERN_MEMORY_RESTART_COPY);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_PROCESSOR_SET);
        RETURN_NAME_FOR_ENUM(KERN_POLICY_LIMIT);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_POLICY);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_OBJECT);
        RETURN_NAME_FOR_ENUM(KERN_ALREADY_WAITING);
        RETURN_NAME_FOR_ENUM(KERN_DEFAULT_SET);
        RETURN_NAME_FOR_ENUM(KERN_EXCEPTION_PROTECTED);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_LEDGER);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_MEMORY_CONTROL);
        RETURN_NAME_FOR_ENUM(KERN_INVALID_SECURITY);
        RETURN_NAME_FOR_ENUM(KERN_NOT_DEPRESSED);
        RETURN_NAME_FOR_ENUM(KERN_TERMINATED);
        RETURN_NAME_FOR_ENUM(KERN_LOCK_SET_DESTROYED);
        RETURN_NAME_FOR_ENUM(KERN_LOCK_UNSTABLE);
        RETURN_NAME_FOR_ENUM(KERN_LOCK_OWNED);
        RETURN_NAME_FOR_ENUM(KERN_LOCK_OWNED_SELF);
        RETURN_NAME_FOR_ENUM(KERN_SEMAPHORE_DESTROYED);
        RETURN_NAME_FOR_ENUM(KERN_RPC_SERVER_TERMINATED);
        RETURN_NAME_FOR_ENUM(KERN_RPC_TERMINATE_ORPHAN);
        RETURN_NAME_FOR_ENUM(KERN_RPC_CONTINUE_ORPHAN);
        RETURN_NAME_FOR_ENUM(KERN_NOT_SUPPORTED);
        RETURN_NAME_FOR_ENUM(KERN_NODE_DOWN);
        RETURN_NAME_FOR_ENUM(KERN_NOT_WAITING);
        RETURN_NAME_FOR_ENUM(KERN_OPERATION_TIMED_OUT);
        RETURN_NAME_FOR_ENUM(KERN_CODESIGN_ERROR);
        // Note: these are only valid for EXC_BAD_ACCESS
        RETURN_NAME_FOR_ENUM(EXC_ARM_DA_ALIGN);
        RETURN_NAME_FOR_ENUM(EXC_ARM_DA_DEBUG);
        RETURN_NAME_FOR_ENUM(EXC_ARM_SP_ALIGN);
        RETURN_NAME_FOR_ENUM(EXC_ARM_SWP);
    }
    return NULL;
}

// ============================================================================
#pragma mark - Thread State Info -
// ============================================================================

#if BSG_HAVE_MACH_THREADS
bool bsg_ksmachfillState(const thread_t thread, const thread_state_t state,
                         const thread_state_flavor_t flavor,
                         const mach_msg_type_number_t stateCount) {
    mach_msg_type_number_t stateCountBuff = stateCount;
    kern_return_t kr;

    kr = thread_get_state(thread, flavor, state, &stateCountBuff);
    if (kr != KERN_SUCCESS) {
        // When running under Rosetta 2, thread_get_state() sometimes fails
        // with MACH_SEND_INVALID_DEST and returns no data.
        BSG_KSLOG_ERROR("thread_get_state: %s", mach_error_string(kr));
        return false;
    }
    return true;
}
#endif

thread_t bsg_ksmachthread_self(void) {
    thread_t thread_self = mach_thread_self();
    mach_port_deallocate(mach_task_self(), thread_self);
    return thread_self;
}

bool bsg_ksmachgetThreadName(const thread_t thread, char *const buffer,
                             size_t bufLength) {
    // WARNING: This implementation is not async-safe because
    // pthread_from_mach_thread_np() acquires an internal lock.

    const pthread_t pthread = pthread_from_mach_thread_np(thread);
    if (pthread == NULL) {
        return false;
    }
    return pthread_getname_np(pthread, buffer, bufLength) == 0;
}

bool bsg_ksmachgetThreadQueueName(const thread_t thread, char *const buffer,
                                  size_t bufLength) {
    // WARNING: This implementation is no longer async-safe!

    integer_t infoBuffer[THREAD_IDENTIFIER_INFO_COUNT] = {0};
    thread_info_t info = infoBuffer;
    mach_msg_type_number_t inOutSize = THREAD_IDENTIFIER_INFO_COUNT;
    kern_return_t kr = 0;

    kr = thread_info(thread, THREAD_IDENTIFIER_INFO, info, &inOutSize);
    if (kr != KERN_SUCCESS) {
        BSG_KSLOG_TRACE("Error getting thread_info with flavor "
                        "THREAD_IDENTIFIER_INFO from mach thread : %s",
                        mach_error_string(kr));
        return false;
    }

    thread_identifier_info_t idInfo = (thread_identifier_info_t)info;
    dispatch_queue_t dispatch_queue = NULL;
    uintptr_t junk = 0;
    // thread_handle shouldn't be 0 also, because
    // identifier_info->dispatch_qaddr =  identifier_info->thread_handle +
    // get_dispatchqueue_offset_from_proc(thread->task->bsd_info);
    if (!idInfo->dispatch_qaddr || !idInfo->thread_handle ||
        // sometimes the queue address is invalid, so avoid dereferencing
        bsg_ksmachcopyMem((const void *)idInfo->dispatch_qaddr, &dispatch_queue,
                          sizeof(dispatch_queue)) != KERN_SUCCESS ||
        // Sometimes dispatch_queue is invalid which causes an EXC_BAD_ACCESS
        // crash in dispatch_queue_get_label(). Check that dispatch_queue can
        // be dereferenced to work around this.
        bsg_ksmachcopyMem((const void *)dispatch_queue, &junk,
                          sizeof(junk)) != KERN_SUCCESS) {
        BSG_KSLOG_TRACE(
            "This thread doesn't have a dispatch queue attached : %u", thread);
        return false;
    }

    // If the thread is being / has recently been destroyed, we can end up with
    // pointers to deallocated memory. Using vm_read_overwrite allows us to
    // avoid crashing in this scenario, but we need to check that the copied
    // data looks like a valid string.
    const void *ptr = dispatch_queue_get_label(dispatch_queue);

    vm_size_t bytesRead = 0;
    // Not using bsg_ksmachcopyMem because it does not return bytesRead
    kr = vm_read_overwrite(mach_task_self(),
                           (vm_address_t)ptr, (vm_size_t)bufLength - 1,
                           (vm_address_t)buffer, &bytesRead);
    if (kr != KERN_SUCCESS) {
        BSG_KSLOG_TRACE("Error while getting dispatch queue name : %p",
                        dispatch_queue);
        buffer[0] = '\0';
        return false;
    }

    buffer[bytesRead] = '\0';

    BSG_KSLOG_TRACE("Dispatch queue name: %s", buffer);

    // Queue label must be a null terminated string.
    size_t iLabel;
    for (iLabel = 0; iLabel < bytesRead; iLabel++) {
        if (buffer[iLabel] < ' ' || buffer[iLabel] > '~') {
            break;
        }
    }
    if (buffer[iLabel] != 0) {
        // Found a non-null, invalid char.
        BSG_KSLOG_TRACE("Queue label contains invalid chars");
        buffer[0] = '\0';
        return false;
    }
    BSG_KSLOG_TRACE("Queue label = %s", buffer);
    return true;
}

integer_t bsg_ksmachgetThreadState(const thread_t thread) {
    integer_t infoBuffer[THREAD_BASIC_INFO_COUNT] = {0};
    thread_info_t info = infoBuffer;
    mach_msg_type_number_t inOutSize = THREAD_BASIC_INFO_COUNT;
    kern_return_t kr = 0;

    kr = thread_info(thread, THREAD_BASIC_INFO, info, &inOutSize);
    if (kr != KERN_SUCCESS) {
        BSG_KSLOG_TRACE("Error getting thread_info with flavor "
                        "THREAD_BASIC_INFO from mach thread : %s",
                        mach_error_string(kr));
        return -1;
    }

    thread_basic_info_t basicInfo = (thread_basic_info_t)info;
    return basicInfo->run_state;
}

// ============================================================================
#pragma mark - Utility -
// ============================================================================

static inline bool isThreadInList(thread_t thread, thread_t *list,
                                  unsigned listCount) {
    for (unsigned i = 0; i < listCount; i++) {
        if (list[i] == thread) {
            return true;
        }
    }
    return false;
}

thread_t *bsg_ksmachgetAllThreads(unsigned *threadCount) {
    kern_return_t kr;
    const task_t thisTask = mach_task_self();
    thread_act_array_t threads;
    mach_msg_type_number_t numThreads;

    if ((kr = task_threads(thisTask, &threads, &numThreads)) != KERN_SUCCESS) {
        BSG_KSLOG_ERROR("task_threads: %s", mach_error_string(kr));
#if !BSG_KSLOG_PRINTS_AT_LEVEL(BSG_KSLogger_Level_Error)
        (void)kr;
#endif
        return NULL;
    }

    *threadCount = numThreads;
    return threads;
}

void bsg_ksmachfreeThreads(thread_t *threads, unsigned threadCount) {
    const task_t thisTask = mach_task_self();
    for (unsigned i = 0; i < threadCount; i++) {
        mach_port_deallocate(thisTask, threads[i]);
    }
    vm_deallocate(thisTask, (vm_address_t)threads,
                  sizeof(*threads) * threadCount);
}

void bsg_ksmachgetThreadStates(thread_t *threads, integer_t *states, unsigned threadCount) {
    for (unsigned i = 0; i < threadCount; i++) {
        states[i] = bsg_ksmachgetThreadState(threads[i]);
    }
}

unsigned bsg_ksmachremoveThreadsFromList(thread_t *srcThreads, unsigned srcThreadCount,
                                         thread_t *omitThreads, unsigned omitThreadsCount,
                                         thread_t *dstThreads, unsigned maxDstThreads) {
    unsigned int iDst = 0;
    for (unsigned iSrc = 0; iSrc < srcThreadCount; iSrc++) {
        if (isThreadInList(srcThreads[iSrc], omitThreads, omitThreadsCount)) {
            continue;
        }
        dstThreads[iDst] = srcThreads[iSrc];
        iDst++;
        if (iDst >= maxDstThreads) {
            break;
        }
    }
    return iDst;
}

#if BSG_HAVE_MACH_THREADS
void bsg_ksmachsuspendThreads(thread_t *threads, unsigned threadsCount) {
    const thread_t thisThread = bsg_ksmachthread_self();
    for (unsigned i = 0; i < threadsCount; i++) {
        thread_t thread = threads[i];
        // IMPORTANT: Never suspend the current thread even if it's in the list!
        if (thread == thisThread) {
            continue;
        }
        kern_return_t kr = thread_suspend(thread);
        if (kr != KERN_SUCCESS) {
            // The thread may have completed running already
            // Don't treat this as a fatal error.
            BSG_KSLOG_DEBUG("thread_suspend (%08x): %s", thread,
                            mach_error_string(kr));
            // Suppress dead store warning when log level > debug
            (void)kr;
        }
    }
}

void bsg_ksmachresumeThreads(thread_t *threads, unsigned threadsCount) {
    const thread_t thisThread = bsg_ksmachthread_self();
    for (unsigned i = 0; i < threadsCount; i++) {
        thread_t thread = threads[i];
        // IMPORTANT: Never resume the current thread even if it's in the list!
        if (thread == thisThread) {
            continue;
        }
        kern_return_t kr = thread_resume(thread);
        if (kr != KERN_SUCCESS) {
            // The thread may have completed running already
            // Don't treat this as a fatal error.
            BSG_KSLOG_DEBUG("thread_resume (%08x): %s", thread,
                            mach_error_string(kr));
            // Suppress dead store warning when log level > debug
            (void)kr;
        }
    }
}
#endif

kern_return_t bsg_ksmachcopyMem(const void *const src, void *const dst,
                                const size_t numBytes) {
    vm_size_t bytesCopied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src,
                             (vm_size_t)numBytes, (vm_address_t)dst,
                             &bytesCopied);
}

double bsg_ksmachtimeDifferenceInSeconds(const uint64_t endTime,
                                         const uint64_t startTime) {
    // From
    // http://lists.apple.com/archives/perfoptimization-dev/2005/Jan/msg00039.html

    static double conversion = 0;

    if (conversion == 0) {
        mach_timebase_info_data_t info = {0};
        kern_return_t kr = mach_timebase_info(&info);
        if (kr != KERN_SUCCESS) {
            BSG_KSLOG_ERROR("mach_timebase_info: %s", mach_error_string(kr));
            return 0;
        }

        conversion = 1e-9 * (double)info.numer / (double)info.denom;
    }

    return conversion * (double)(endTime - startTime);
}

/** Check if the current process is being traced or not.
 *
 * @return true if we're being traced.
 */
bool bsg_ksmachisBeingTraced(void) {
    struct kinfo_proc procInfo;
    size_t structSize = sizeof(procInfo);
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};

    if (sysctl(mib, sizeof(mib) / sizeof(*mib), &procInfo, &structSize, NULL,
               0) != 0) {
        BSG_KSLOG_ERROR("sysctl: %s", strerror(errno));
        return false;
    }

    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
}
