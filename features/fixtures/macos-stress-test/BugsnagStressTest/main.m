//
//  main.m
//  BugsnagStressTest
//
//  Created by Nick Dowell on 04/03/2021.
//

#import <Bugsnag/Bugsnag.h>

#import <mach/mach_init.h>
#import <mach/task.h>
#import <mach/task_info.h>

static NSString * const kNotifyEndpoint = @"http://localhost:9339/notify";

static const int kNumberOfIterations = 5000;

static const NSInteger kMaxConcurrentNotifies = 8;

// Note: memory usage increases in line with the number of threads and config.maxPersistedEvents
static const mach_vm_size_t kMemoryLimit = 45 * 1024 * 1024;

int main(int argc, const char * argv[]) {
    if (getenv("QUIET")) {
        freopen("BugsnagStressTest.stdout.log", "w", stdout);
        freopen("BugsnagStressTest.stderr.log", "w", stderr);
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    NSOperationQueue *notifyQueue = [[NSOperationQueue alloc] init];
    notifyQueue.maxConcurrentOperationCount = kMaxConcurrentNotifies;
    
    BugsnagClient *bugsnagClient = nil;
    
    @autoreleasepool {
        [NSFileManager.defaultManager removeItemAtURL:
         [[NSFileManager.defaultManager
           URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask
           appropriateForURL:nil create:NO error:nil]
          URLByAppendingPathComponent:@"com.bugsnag.Bugsnag"] error:nil];
        
        BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];
        config.apiKey = @"0192837465afbecd0192837465afbecd";
        config.autoDetectErrors = NO;
        config.endpoints.notify = kNotifyEndpoint;
        bugsnagClient = [Bugsnag startWithConfiguration:config];
        
        // These threads make a deadlock more likely if any of the notify threads are doing something they shouldn't.
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSThread.currentThread.name = @"com.bugsnag.stress-test-malloc";
            while (1) {
                free(malloc(1024 * 1024));
            }
        });
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSThread.currentThread.name = @"com.bugsnag.stress-test-objc";
            while (1) {
                @autoreleasepool {
                    [[NSArray arrayWithObjects:@0, @1, @3, @4, nil] sortedArrayUsingSelector:@selector(compare:)];
                }
            }
        });
        
        for (int i = 0; i < kNumberOfIterations; i++) {
            [notifyQueue addOperationWithBlock:^{
                NSError *error = [NSError errorWithDomain:@"BugsnagStressTest" code:random() userInfo:nil];
                [Bugsnag notifyError:error block:^BOOL(BugsnagEvent *event) {
                    return YES;
                }];
            }];
        }
    }
    
    NSLog(@"Starting main run loop...");
    
    mach_vm_size_t maxFootprint = 0;
    
    while (notifyQueue.operationCount) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        
        // Memory watchdog that terminates the app if Bugsnag is using too much memory.
        // setrlimit() and ulimit are not able to limit memory usage on macOS.
        task_vm_info_data_t task_vm_info = {0};
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&task_vm_info, &count);
        maxFootprint = MAX(maxFootprint, task_vm_info.phys_footprint);
        if (task_vm_info.phys_footprint > kMemoryLimit) {
            NSLog(@"💥 Memory limit (%d MB) exceeded", (int)kMemoryLimit / (1024 * 1024));
            abort();
        }
    }
    
    NSLog(@"Ran in %f seconds", CFAbsoluteTimeGetCurrent() - startTime);
    NSLog(@"Maximum memory usage: %.1f MB", maxFootprint / (1024.0 * 1024.0));
    
    NSOperationQueue *uploadQueue = [bugsnagClient valueForKeyPath:@"eventUploader.uploadQueue"];
    NSLog(@"Waiting for all uploads to finish...");
    [uploadQueue waitUntilAllOperationsAreFinished];
    NSLog(@"All uploads have finished.");
    
    return 0;
}
