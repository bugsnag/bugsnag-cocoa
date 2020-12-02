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
#import <mach/mach_time.h>


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

- (void) testFreeMemory
{
    uint64_t freeMem = bsg_ksmachfreeMemory();
    XCTAssertTrue(freeMem > 0, @"");
}

- (void) testUsableMemory
{
    uint64_t usableMem = bsg_ksmachusableMemory();
    XCTAssertTrue(usableMem > 0, @"");
}

- (void) testSuspendThreads
{
    bool success;
    success = bsg_ksmachsuspendAllThreads();
    XCTAssertTrue(success, @"");
    success = bsg_ksmachresumeAllThreads();
    XCTAssertTrue(success, @"");
}

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

- (void) testCopyMaxPossibleMem
{
    char buff[1000];
    char buff2[5] = {1,2,3,4,5};
    
    size_t copied = bsg_ksmachcopyMaxPossibleMem(buff2, buff, sizeof(buff));
    XCTAssertTrue(copied >= 5, @"");
    int memCmpResult = memcmp(buff, buff2, sizeof(buff2));
    XCTAssertEqual(memCmpResult, 0, @"");
}

- (void) testCopyMaxPossibleMemNull
{
    char buff[1000];
    char* buff2 = NULL;
    
    size_t copied = bsg_ksmachcopyMaxPossibleMem(buff2, buff, sizeof(buff));
    XCTAssertTrue(copied == 0, @"");
}

- (void) testCopyMaxPossibleMemBad
{
    char buff[1000];
    char* buff2 = (char*)-1;
    
    size_t copied = bsg_ksmachcopyMaxPossibleMem(buff2, buff, sizeof(buff));
    XCTAssertTrue(copied == 0, @"");
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

// TODO: Disabling this until I figure out what's wrong with queue names.
//- (void) testGetQueueName
//{
//    kern_return_t kr;
//    const task_t thisTask = mach_task_self();
//    thread_act_array_t threads;
//    mach_msg_type_number_t numThreads;
//    
//    kr = task_threads(thisTask, &threads, &numThreads);
//    XCTAssertTrue(kr == KERN_SUCCESS, @"");
//    
//    bool success = false;
//    char buffer[100];
//    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
//    {
//        thread_t thread = threads[i];
//        if(bsg_ksmachgetThreadQueueName(thread, buffer, sizeof(buffer)))
//        {
//            success = true;
//            break;
//        }
//    }
//    
//    for(mach_msg_type_number_t i = 0; i < numThreads; i++)
//    {
//        mach_port_deallocate(thisTask, threads[i]);
//    }
//    vm_deallocate(thisTask, (vm_address_t)threads, sizeof(thread_t) * numThreads);
//    
//    XCTAssertTrue(success, @"");
//}

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

- (void) testStackGrowDirection
{
    bsg_ksmachstackGrowDirection();
}

@end
