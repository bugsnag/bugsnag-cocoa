//
//  bsg_ksmachTests.m
//
//  Created by Karl Stenerud on 2012-03-03.
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


#import <XCTest/XCTest.h>

#import "BSG_KSMach.h"
#import "BSG_KSMachApple.h"
#import "BSGDefines.h"

#import <mach/mach_time.h>
#import <sys/sysctl.h>


@interface TestThread: NSThread

@property(nonatomic, readwrite, assign) thread_t thread;

@end

@implementation TestThread

@synthesize thread = _thread;

- (void) main
{
    self.thread = bsg_ksmachthread_self();
    while(!self.isCancelled)
    {
        [[self class] sleepForTimeInterval:0.1];
    }
}

@end


void * executeBlock(void *ptr)
{
    ((__bridge_transfer dispatch_block_t)ptr)();
    return NULL;
}


@interface bsg_ksmachTests : XCTestCase @end

@implementation bsg_ksmachTests

- (void) testExceptionName
{
    NSString* expected = @"EXC_ARITHMETIC";
    NSString* actual = [NSString stringWithCString:bsg_ksmachexceptionName(EXC_ARITHMETIC)
                                          encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(actual, expected, @"");
}

- (void) testVeryHighExceptionName
{
    const char* result = bsg_ksmachexceptionName(100000);
    XCTAssertTrue(result == NULL, @"");
}

- (void) testKernReturnCodeName
{
    NSString* expected = @"KERN_FAILURE";
    NSString* actual = [NSString stringWithCString:bsg_ksmachkernelReturnCodeName(KERN_FAILURE)
                                          encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(actual, expected, @"");
}

- (void) testArmExcBadAccessKernReturnCodeNames
{
    XCTAssertEqualObjects(@(bsg_ksmachkernelReturnCodeName(EXC_ARM_DA_ALIGN)), @"EXC_ARM_DA_ALIGN");
    XCTAssertEqualObjects(@(bsg_ksmachkernelReturnCodeName(EXC_ARM_DA_DEBUG)), @"EXC_ARM_DA_DEBUG");
    XCTAssertEqualObjects(@(bsg_ksmachkernelReturnCodeName(EXC_ARM_SP_ALIGN)), @"EXC_ARM_SP_ALIGN");
    XCTAssertEqualObjects(@(bsg_ksmachkernelReturnCodeName(EXC_ARM_SWP)), @"EXC_ARM_SWP");
}

- (void) testVeryHighKernReturnCodeName
{
    const char* result = bsg_ksmachkernelReturnCodeName(100000);
    XCTAssertTrue(result == NULL, @"");
}

#if BSG_HAVE_MACH_THREADS
- (void) testSuspendThreads
{
#if TARGET_CPU_X86_64 && defined(XCTSkipIf)
    int translated = 0;
    size_t size = sizeof(translated);
    sysctlbyname("sysctl.proc_translated", &translated, &size, NULL, 0);
    XCTSkipIf(translated, @"Can deadlock under Rosetta");
#endif
    
    // Just make sure that suspending and resuming doesn't hang the process.
    unsigned threadsCount = 0;
    thread_t *threads = bsg_ksmachgetAllThreads(&threadsCount);
    bsg_ksmachsuspendThreads(threads, threadsCount);
    bsg_ksmachresumeThreads(threads, threadsCount);
}
#endif

- (void) testCopyMem
{
    char buff[100];
    char buff2[100] = {1,2,3,4,5};
    
    kern_return_t result = bsg_ksmachcopyMem(buff2, buff, sizeof(buff));
    XCTAssertEqual(result, KERN_SUCCESS, @"");
    int memCmpResult = memcmp(buff, buff2, sizeof(buff));
    XCTAssertEqual(memCmpResult, 0, @"");
}

- (void) testCopyMemNull
{
    char buff[100];
    char* buff2 = NULL;
    
    kern_return_t result = bsg_ksmachcopyMem(buff2, buff, sizeof(buff));
    XCTAssertTrue(result != KERN_SUCCESS, @"");
}

- (void) testCopyMemBad
{
    char buff[100];
    char* buff2 = (char*)-1;
    
    kern_return_t result = bsg_ksmachcopyMem(buff2, buff, sizeof(buff));
    XCTAssertTrue(result != KERN_SUCCESS, @"");
}

- (void) testTimeDifferenceInSeconds
{
    uint64_t startTime = mach_absolute_time();
    CFAbsoluteTime cfStartTime = CFAbsoluteTimeGetCurrent();
    [NSThread sleepForTimeInterval:0.1];
    uint64_t endTime = mach_absolute_time();
    CFAbsoluteTime cfEndTime = CFAbsoluteTimeGetCurrent();
    double diff = bsg_ksmachtimeDifferenceInSeconds(endTime, startTime);
    double cfDiff = cfEndTime - cfStartTime;
    XCTAssertEqualWithAccuracy(diff, cfDiff, 0.001);
}

- (void) testGetQueueNameWithMainThread
{
    char name[32] = "";

    XCTAssertTrue(bsg_ksmachgetThreadQueueName(bsg_ksmachthread_self(),
                                               name, sizeof(name)));

    XCTAssertEqualObjects(@(name), @"com.apple.main-thread");
}

- (void) testGetQueueNameWithNonDispatchThread
{
    pthread_t thread;

    pthread_create(&thread, NULL, executeBlock,
                   (__bridge_retained void *)^{
        char name[32] = "";

        XCTAssertFalse(bsg_ksmachgetThreadQueueName(bsg_ksmachthread_self(),
                                                    name, sizeof(name)));
    });

    pthread_join(thread, NULL);
}

- (void) testGetQueueNameWithInvalidThread
{
    char name[32] = "";
    
    XCTAssertFalse(bsg_ksmachgetThreadQueueName(0xdeadbeef,
                                                name, sizeof(name)));
}

- (void) testGetQueueNameWithEphemeralThreads
{
    //
    // This test aims to trigger potential crashes when getting the queue name
    // of dying / recently deceased threads.
    //
    // For more effective detection of bugs, enable "Malloc Scribble" under the
    // Scheme's Diagnostics options, or set the "MallocScribble" environment
    // variable.
    //
    
    __block int finished = 0;
    
    dispatch_async(dispatch_queue_create(NULL, 0), ^{
        dispatch_group_t group = dispatch_group_create();

        for (int i = 0; i < 100000; i++) {
            char *label = NULL;
            asprintf(&label, "%d", i);
            dispatch_group_async(group, dispatch_queue_create(label, 0), ^{
                usleep(10);
            });
            free(label);
        }

        dispatch_group_notify(group, dispatch_queue_create(NULL, 0), ^{
            finished = 1;
        });
    });
    
    while (!finished) {
        char name[5];
        thread_act_array_t threads;
        mach_msg_type_number_t i, threadCount = 0;
        task_threads(mach_task_self(), &threads, &threadCount);

        for (i = 0; i < threadCount; i++) {
            bzero(name, sizeof(name));
            if (bsg_ksmachgetThreadQueueName(threads[i], name, sizeof(name))) {
                XCTAssertEqual(name[sizeof(name) - 1], '\0',
                               @"queue name must be NULL terminated");
            }
        }

        vm_deallocate(mach_task_self(), (vm_address_t)threads,
                      sizeof(threads[0]) * threadCount);
    }
}

#if BSG_HAVE_MACH_THREADS
- (void) testThreadState
{
    TestThread* thread = [[TestThread alloc] init];
    [thread start];
    [NSThread sleepForTimeInterval:0.1];
    kern_return_t kr;
    kr = thread_suspend(thread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"");
    
    _STRUCT_MCONTEXT machineContext;
    bool success = bsg_ksmachthreadState(thread.thread, &machineContext);
    XCTAssertTrue(success, @"");

    int numRegisters = bsg_ksmachnumRegisters();
    for(int i = 0; i < numRegisters; i++)
    {
        const char* name = bsg_ksmachregisterName(i);
        XCTAssertTrue(name != NULL, @"Register %d was NULL", i);
        bsg_ksmachregisterValue(&machineContext, i);
    }

    const char* name = bsg_ksmachregisterName(1000000);
    XCTAssertTrue(name == NULL, @"");
    uint64_t value = bsg_ksmachregisterValue(&machineContext, 1000000);
    XCTAssertTrue(value == 0, @"");
    
    uintptr_t address;
    address = bsg_ksmachframePointer(&machineContext);
    XCTAssertTrue(address != 0, @"");
    address = bsg_ksmachstackPointer(&machineContext);
    XCTAssertTrue(address != 0, @"");
    address = bsg_ksmachinstructionAddress(&machineContext);
    XCTAssertTrue(address != 0, @"");

    thread_resume(thread.thread);
    [thread cancel];
}

- (void) testFloatState
{
    TestThread* thread = [[TestThread alloc] init];
    [thread start];
    [NSThread sleepForTimeInterval:0.1];
    kern_return_t kr;
    kr = thread_suspend(thread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"");
    
    _STRUCT_MCONTEXT machineContext;
    bool success = bsg_ksmachfloatState(thread.thread, &machineContext);
    XCTAssertTrue(success, @"");
    thread_resume(thread.thread);
    [thread cancel];
}

- (void) testExceptionState
{
    TestThread* thread = [[TestThread alloc] init];
    [thread start];
    [NSThread sleepForTimeInterval:0.1];
    kern_return_t kr;
    kr = thread_suspend(thread.thread);
    XCTAssertTrue(kr == KERN_SUCCESS, @"");
    
    _STRUCT_MCONTEXT machineContext;
    bool success = bsg_ksmachexceptionState(thread.thread, &machineContext);
    XCTAssertTrue(success, @"");
    
    int numRegisters = bsg_ksmachnumExceptionRegisters();
    for(int i = 0; i < numRegisters; i++)
    {
        const char* name = bsg_ksmachexceptionRegisterName(i);
        XCTAssertTrue(name != NULL, @"Register %d was NULL", i);
        bsg_ksmachexceptionRegisterValue(&machineContext, i);
    }
    
    const char* name = bsg_ksmachexceptionRegisterName(1000000);
    XCTAssertTrue(name == NULL, @"");
    uint64_t value = bsg_ksmachexceptionRegisterValue(&machineContext, 1000000);
    XCTAssertTrue(value == 0, @"");

    bsg_ksmachfaultAddress(&machineContext);

    thread_resume(thread.thread);
    [thread cancel];
}
#endif

- (void) testStackGrowDirection
{
    bsg_ksmachstackGrowDirection();
}

- (void) testRemoveThreadsFromList
{
    thread_t src[] = {1, 2, 3};
    thread_t dst[] = {0, 0, 0};
    bsg_ksmachremoveThreadsFromList(src, 3, NULL, 0, dst, 2);
    XCTAssertEqual(1, dst[0]);
    XCTAssertEqual(2, dst[1]);
    XCTAssertEqual(0, dst[2]);
}

- (void) testRemoveThreadsFromList2
{
    thread_t src[] = {1, 2, 3, 4};
    thread_t omit[] = {2, 4};
    thread_t dst[] = {0, 0, 0, 0};
    int count = bsg_ksmachremoveThreadsFromList(src, 4, omit, 2, dst, 3);
    XCTAssertEqual(1, dst[0]);
    XCTAssertEqual(3, dst[1]);
    XCTAssertEqual(0, dst[2]);
    XCTAssertEqual(0, dst[3]);
    XCTAssertEqual(2, count);
}

- (void) testRemoveThreadsFromList3
{
    thread_t src[] = {1, 2, 3, 4, 5, 6};
    thread_t omit[] = {2, 4};
    thread_t dst[] = {0, 0, 0, 0, 0, 0};
    int count = bsg_ksmachremoveThreadsFromList(src, 6, omit, 2, dst, 3);
    XCTAssertEqual(1, dst[0]);
    XCTAssertEqual(3, dst[1]);
    XCTAssertEqual(5, dst[2]);
    XCTAssertEqual(0, dst[3]);
    XCTAssertEqual(0, dst[4]);
    XCTAssertEqual(0, dst[5]);
    XCTAssertEqual(3, count);
}

#pragma mark - EXC_GUARD

#define GUARD_CODE(type, flavor, target) \
    ((int64_t)(((uint64_t)(type) << 61) | ((uint64_t)(flavor) << 32) | (uint32_t)(target)))

- (void)testGuardExceptionName {
    XCTAssertEqualObjects(@(bsg_ksmachexceptionName(EXC_GUARD)), @"EXC_GUARD");
}

- (void)testGuardTypeValuesMatchSDK {
    XCTAssertEqual(BSG_GUARD_TYPE_MACH_PORT, GUARD_TYPE_MACH_PORT);
    XCTAssertEqual(BSG_GUARD_TYPE_VIRT_MEMORY, GUARD_TYPE_VIRT_MEMORY);
}

- (void)testGuardDecodeFileDescriptor {
    // Delivered by macOS 26.6.1 for close() of a guarded fd 3 (see the
    // EXC_GUARD validation notes); used here as a synthetic fixture.
    const int64_t code = (int64_t)0x4000000100000003ULL;
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TYPE(code), BSG_GUARD_TYPE_FD);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_FLAVOR(code), 1ULL);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TARGET(code), 3U);
    XCTAssertEqualObjects(@(bsg_ksmachguardTypeName(BSG_GUARD_TYPE_FD)), @"GUARD_TYPE_FD");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_FD, 1)), @"kGUARD_EXC_CLOSE");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_FD, 1u << 6)), @"kGUARD_EXC_WRITE");
    XCTAssertTrue(bsg_ksmachguardIsFatal(code));
}

- (void)testGuardDecodeMachPort {
    // Delivered by macOS 26.6.1 for mach_port_destruct() of guarded port 0xb03.
    const int64_t code = (int64_t)0x2000000100000b03ULL;
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TYPE(code), BSG_GUARD_TYPE_MACH_PORT);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_FLAVOR(code), (uint64_t)kGUARD_EXC_DESTROY);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TARGET(code), 0xb03U);
    XCTAssertEqualObjects(@(bsg_ksmachguardTypeName(BSG_GUARD_TYPE_MACH_PORT)), @"GUARD_TYPE_MACH_PORT");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_DESTROY)), @"kGUARD_EXC_DESTROY");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_INCORRECT_GUARD)), @"kGUARD_EXC_INCORRECT_GUARD");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_MSG_FILTERED)), @"kGUARD_EXC_MSG_FILTERED");
    XCTAssertTrue(bsg_ksmachguardIsFatal(code));
}

- (void)testGuardDecodeFullWidthValues {
    // All flavor bits and a target with the top bit set.
    const int64_t code = GUARD_CODE(BSG_GUARD_TYPE_REJECTED_SC, 0x1fffffff, 0xffffffff);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TYPE(code), BSG_GUARD_TYPE_REJECTED_SC);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_FLAVOR(code), 0x1fffffffULL);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TARGET(code), 0xffffffffU);
    // Type 7 sets the sign bit of the int64_t code.
    const int64_t negative = GUARD_CODE(7, 1, 1);
    XCTAssertLessThan(negative, 0);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_TYPE(negative), 7ULL);
    XCTAssertEqual(BSG_EXC_GUARD_DECODE_GUARD_FLAVOR(negative), 1ULL);
}

- (void)testGuardUnknownValuesHaveNoNames {
    XCTAssertTrue(bsg_ksmachguardTypeName(7) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_FD, 1u << 7) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_FD, 0) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, 14) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, 1u << 20) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 0) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 3) == NULL);
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 200 /* kGUARD_EXC_MTE_SYNC_FAULT */) == NULL);
    // No flavor names are claimed for types whose flavors aren't decoded.
    XCTAssertTrue(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VN, 1) == NULL);
}

- (void)testGuardFatality {
    // File descriptor guards: always fatal, including unknown flavors.
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_FD, 1, 5)));
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_FD, 1u << 7, 5)));

    // Mach port guards: only the always-fatal reasons.
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 0 /* kGUARD_EXC_NONE */, 1)));
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_DESTROY, 1)));
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_IMMOVABLE, 1)));
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, MAX_FATAL_kGUARD_EXC_CODE, 1)));
    // Optional reasons are fatal only when the task has TASK_EXC_GUARD_MP_FATAL (see testGuardFatalityDependsOnTaskPolicy).
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 0x00100000 /* kGUARD_EXC_RCV_GUARDED_DESC */, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 1u << 21 /* kGUARD_EXC_MOD_REFS_NON_FATAL */, 1)));

    // Vnode guards: fatal except VNG_PERMISSIONS (1 << 7).
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_VN, 1u << 0, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_VN, 1u << 7, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_VN, 0, 1)));

    // Types whose fatality can't be determined from the code are never fatal.
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_NONE, 1, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_USER, 0, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_REJECTED_SC, 0, 1)));
    XCTAssertFalse(bsg_ksmachguardIsFatal(GUARD_CODE(7, 1, 1)));
}

- (void)testGuardVirtualMemoryAndPortFlavorNames {
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 1)), @"kGUARD_EXC_DEALLOC_GAP");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 9)), @"kGUARD_EXC_RECLAIM_ACCOUNTING_FAILURE");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_VIRT_MEMORY, 101)), @"kGUARD_EXC_SEC_SHARING_DENIED");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_INVALID_RIGHT)), @"kGUARD_EXC_INVALID_RIGHT");
    XCTAssertEqualObjects(@(bsg_ksmachguardFlavorName(BSG_GUARD_TYPE_MACH_PORT, 1u << 19)), @"kGUARD_EXC_RCV_INVALID_NAME");
}

- (void)testGuardFatalityDependsOnTaskPolicy {
    const int64_t vm = GUARD_CODE(BSG_GUARD_TYPE_VIRT_MEMORY, 1 /* kGUARD_EXC_DEALLOC_GAP */, 0);
    const int64_t vmOther = GUARD_CODE(BSG_GUARD_TYPE_VIRT_MEMORY, 200, 0);
    const int64_t optionalPort = GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 256 /* kGUARD_EXC_INVALID_RIGHT */, 1);
    const int64_t lastOptionalPort = GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 1u << 19 /* MAX_OPTIONAL_kGUARD_EXC_CODE */, 1);
    const int64_t softPort = GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 0x00100000 /* kGUARD_EXC_RCV_GUARDED_DESC */, 1);
    const int64_t nonFatalPort = GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 1u << 21 /* kGUARD_EXC_MOD_REFS_NON_FATAL */, 1);
    const uint32_t vmFatal = 0x08, vmDeliverOnly = 0x01, mpFatal = 0x80, mpDeliverOnly = 0x10;

    // Virtual memory: only the VM FATAL bit matters, for every flavor.
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(vm, 0));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(vm, vmDeliverOnly));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(vm, mpFatal));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(vm, vmFatal));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(vm, vmFatal | vmDeliverOnly));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(vmOther, vmFatal));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(vmOther, 0));

    // Optional Mach port reasons: only the MP FATAL bit matters.
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(optionalPort, 0));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(optionalPort, mpDeliverOnly));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(optionalPort, vmFatal));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(optionalPort, mpFatal));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(lastOptionalPort, mpFatal));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(lastOptionalPort, 0));
    // Reasons above the optional range stay non-fatal whatever the policy.
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(softPort, 0xff));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(nonFatalPort, 0xff));

    // Always-fatal guards ignore the policy.
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_FD, 1, 5), 0));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, kGUARD_EXC_DESTROY, 1), 0));
    XCTAssertTrue(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_VN, 1, 1), 0));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_VN, 1u << 7, 1), 0xff));

    // User, rejected syscall and unknown types are never fatal, even with every bit set.
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_USER, 0, 1), 0xff));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_REJECTED_SC, 0, 1), 0xff));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(BSG_GUARD_TYPE_NONE, 1, 1), 0xff));
    XCTAssertFalse(bsg_ksmachguardIsFatalWithPolicy(GUARD_CODE(7, 1, 1), 0xff));
}

- (void)testGuardFatalityUsesTheTasksOwnPolicy {
    // The live check must agree with whatever policy this test process has.
    task_exc_guard_behavior_t behavior = 0;
    XCTAssertEqual(task_get_exc_guard_behavior(mach_task_self(), &behavior), KERN_SUCCESS);
    const int64_t vm = GUARD_CODE(BSG_GUARD_TYPE_VIRT_MEMORY, 1, 0);
    const int64_t optionalPort = GUARD_CODE(BSG_GUARD_TYPE_MACH_PORT, 256, 1);
    XCTAssertEqual(bsg_ksmachguardIsFatal(vm), (behavior & TASK_EXC_GUARD_VM_FATAL) != 0);
    XCTAssertEqual(bsg_ksmachguardIsFatal(optionalPort), (behavior & TASK_EXC_GUARD_MP_FATAL) != 0);
    XCTAssertTrue(bsg_ksmachguardIsFatal(GUARD_CODE(BSG_GUARD_TYPE_FD, 1, 1)));
}

#if BSG_HAVE_MACH_EXCEPTIONS

extern void bsg_ksmachexc_i_makeReplyHeader(const mach_msg_header_t *request, mach_msg_header_t *reply, mach_msg_size_t replySize);
extern bool bsg_ksmachexc_i_hasTaskExceptionHandler(task_t task, exception_mask_t mask);

- (void)testExceptionReplyHeader {
    // Header of a real EXC_GUARD request received on macOS 26.6.1.
    mach_msg_header_t request = {0};
    request.msgh_bits = 0x80001112; // complex | local MOVE_SEND | remote MOVE_SEND_ONCE
    request.msgh_remote_port = 0xc03;
    request.msgh_local_port = 0x1e03;
    request.msgh_id = 2405; // mach_exception_raise
    mach_msg_header_t reply;
    memset(&reply, 0xff, sizeof(reply));
    bsg_ksmachexc_i_makeReplyHeader(&request, &reply, 36);
    XCTAssertEqual(reply.msgh_bits, (mach_msg_bits_t)MACH_MSG_TYPE_MOVE_SEND_ONCE);
    XCTAssertEqual(reply.msgh_bits & MACH_MSGH_BITS_COMPLEX, 0U);
    XCTAssertEqual(reply.msgh_remote_port, (mach_port_t)0xc03);
    // Must not move a send right for our own exception port.
    XCTAssertEqual(reply.msgh_local_port, (mach_port_t)MACH_PORT_NULL);
    XCTAssertEqual(reply.msgh_voucher_port, (mach_port_t)MACH_PORT_NULL);
    XCTAssertEqual(reply.msgh_size, 36U);
    XCTAssertEqual(reply.msgh_id, 2505);
}

- (void)testHasTaskExceptionHandler {
    task_t task = mach_task_self();
    exception_mask_t masks[EXC_TYPES_COUNT];
    exception_handler_t ports[EXC_TYPES_COUNT];
    exception_behavior_t behaviors[EXC_TYPES_COUNT];
    thread_state_flavor_t flavors[EXC_TYPES_COUNT];
    mach_msg_type_number_t count = EXC_TYPES_COUNT;
    XCTAssertEqual(task_get_exception_ports(task, EXC_MASK_GUARD, masks, &count, ports, behaviors, flavors), KERN_SUCCESS);

    mach_port_t port = MACH_PORT_NULL;
    XCTAssertEqual(mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &port), KERN_SUCCESS);
    XCTAssertEqual(mach_port_insert_right(task, port, port, MACH_MSG_TYPE_MAKE_SEND), KERN_SUCCESS);

    XCTAssertEqual(task_set_exception_ports(task, EXC_MASK_GUARD, MACH_PORT_NULL, EXCEPTION_DEFAULT, THREAD_STATE_NONE), KERN_SUCCESS);
    XCTAssertFalse(bsg_ksmachexc_i_hasTaskExceptionHandler(task, EXC_MASK_GUARD));
    XCTAssertEqual(task_set_exception_ports(task, EXC_MASK_GUARD, port, (int)(EXCEPTION_DEFAULT | MACH_EXCEPTION_CODES), THREAD_STATE_NONE), KERN_SUCCESS);
    XCTAssertTrue(bsg_ksmachexc_i_hasTaskExceptionHandler(task, EXC_MASK_GUARD));

    // Restore whatever was installed before.
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        task_set_exception_ports(task, masks[i], ports[i], behaviors[i], flavors[i]);
    }
    mach_port_destruct(task, port, -1, 0);
}

#endif

@end
