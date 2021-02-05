//
//  BugsnagThread+Recording.m
//  Bugsnag
//
//  Created by Nick Dowell on 05/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BugsnagThread+Recording.h"

#import "BugsnagStackframe+Private.h"
#import "BugsnagThread+Private.h"

#include "BSG_KSBacktrace_Private.h"
#include "BSG_KSCrashSentry_User.h"
#include "BSG_KSMach.h"

#include <execinfo.h>


#define kMaxAddresses 150 // same as BSG_kMaxBacktraceDepth

struct backtrace_t {
    int length;
    uintptr_t addresses[kMaxAddresses];
};


@implementation BugsnagThread (Recording)

static void bsg_backtrace(thread_t thread, struct backtrace_t *output) {
    output->length = 0;
    if (thread == bsg_ksmachthread_self()) {
        output->length = backtrace((void **)output->addresses, kMaxAddresses);
        return;
    }
    BSG_STRUCT_MCONTEXT_L machineContext;
    if (bsg_ksmachthreadState(thread, &machineContext)) {
        output->length = bsg_ksbt_backtraceThreadState(&machineContext, output->addresses, 0, kMaxAddresses);
    }
}

+ (nullable NSArray<BugsnagThread *> *)allThreadsWithSkippedFrames:(int)skippedFrames {
    thread_t *threads = NULL;
    mach_msg_type_number_t threadCount = 0;
    
    bsg_kscrashsentry_suspend_threads_user();
    
    // While threads are suspended only async-signal-safe functions should be used,
    // as another threads may have been suspended while holding a lock.
    
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
        bsg_kscrashsentry_resume_threads_user(false);
        return nil;
    }
    
    struct backtrace_t backtraces[threadCount];
    
    for (int i = 0; i < threadCount; i++) {
        bsg_backtrace(threads[i], &backtraces[i]);
    }
    
    bsg_kscrashsentry_resume_threads_user(false);
    
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:threadCount];
    
    for (int i = 0; i < threadCount; i++) {
        BOOL isCurrentThread = MACH_PORT_INDEX(threads[i]) == MACH_PORT_INDEX(bsg_ksmachthread_self());
        int skip = 0;
        if (isCurrentThread && backtraces[i].length > (skippedFrames + 2)) {
            skip = skippedFrames + 2; // +2 to account for this method and bsg_backtrace()
        }
        [objects addObject:[[BugsnagThread alloc] initWithMachThread:threads[i]
                                                  backtraceAddresses:backtraces[i].addresses + skip
                                                     backtraceLength:backtraces[i].length - skip
                                                errorReportingThread:isCurrentThread
                                                               index:i]];
    }
    
    for (int i = 0; i < threadCount; i++) {
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * threadCount);
    
    return objects;
}

+ (instancetype)currentThreadWithSkippedFrames:(int)skippedFrames {
    thread_t thread = mach_thread_self();
    struct backtrace_t backtrace;
    bsg_backtrace(thread, &backtrace);
    thread_t *threads = NULL;
    mach_msg_type_number_t threadCount = 0;
    int threadIndex = 0;
    if (task_threads(mach_task_self(), &threads, &threadCount) == KERN_SUCCESS) {
        for (int i = 0; i < threadCount; i++) {
            if (MACH_PORT_INDEX(threads[i]) == MACH_PORT_INDEX(thread)) {
                threadIndex = i;
            }
            mach_port_deallocate(mach_task_self(), threads[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * threadCount);
    }
    int skip = MIN(skippedFrames + 2, backtrace.length); // +2 to account for this method and bsg_backtrace()
    BugsnagThread *object = [[BugsnagThread alloc] initWithMachThread:thread
                                                   backtraceAddresses:backtrace.addresses + skip
                                                      backtraceLength:backtrace.length - skip
                                                 errorReportingThread:YES
                                                                index:threadIndex];
    mach_port_deallocate(mach_task_self(), thread);
    return object;
}

+ (nullable instancetype)mainThread {
    if ([NSThread isMainThread]) {
        return [BugsnagThread currentThreadWithSkippedFrames:1];
    }
    
    thread_t *threads = NULL;
    mach_msg_type_number_t threadCount = 0;
    if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
        return nil;
    }
    
    BugsnagThread *object = nil;
    if (threadCount) {
        thread_t thread = threads[0];
        struct backtrace_t backtrace;
        BOOL needsResume = NO;
        needsResume = thread_suspend(thread) == KERN_SUCCESS;
        bsg_backtrace(thread, &backtrace);
        if (needsResume) {
            thread_resume(thread);
        }
        object = [[BugsnagThread alloc] initWithMachThread:thread
                                        backtraceAddresses:backtrace.addresses
                                           backtraceLength:backtrace.length
                                      errorReportingThread:YES
                                                     index:0];
    }
    
    for (int i = 0; i < threadCount; i++) {
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * threadCount);
    
    return object;
}

- (instancetype)initWithMachThread:(thread_t)machThread
                backtraceAddresses:(uintptr_t *)backtraceAddresses
                   backtraceLength:(int)backtraceLength
              errorReportingThread:(BOOL)errorReportingThread
                             index:(int)index {
    
    // Match the way Xcode's UI displays thread names
    NSString *name = nil;
    char buffer[64] = "";
    if (bsg_ksmachgetThreadName(machThread, buffer, sizeof(buffer)) && buffer[0]) {
        name = [NSString stringWithFormat:@"%s (%d)", buffer, index + 1];
    } else if (bsg_ksmachgetThreadQueueName(machThread, buffer, sizeof(buffer)) && buffer[0]) {
        name = [NSString stringWithFormat:@"Thread %d Queue: %s", index + 1, buffer];
    } else {
        name = [NSString stringWithFormat:@"Thread %d", index + 1];
    }
    
    return [self initWithId:[NSString stringWithFormat:@"%d", index]
                       name:name
       errorReportingThread:errorReportingThread
                 stacktrace:[BugsnagStackframe stackframesWithBacktrace:backtraceAddresses length:backtraceLength]
                       type:BSGThreadTypeCocoa];
}

@end
