//
//  ViewController.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "ViewController.h"
#import "OutOfMemoryController.h"
#import "Bugsnag.h"
#import <pthread.h>
#import <stdlib.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [Bugsnag leaveBreadcrumbWithMessage:@"Received memory warning"];
}

/**
 This method generates an out-of-memory (OOM) exception.  The method of generating this error can be seen in the `OutOfMemoryController` file.
 
 When this low memory state occurs the application will be closed by the operating system and an OOM error report delivered to your Bugsnag dashboard.
 */
- (IBAction)crashMemoryPressure:(id)sender {
    OutOfMemoryController *controller = [OutOfMemoryController new];
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)crashUncaughtException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"Generating exception by non-existent selector"];
    [self performSelectorOnMainThread:@selector(someRandomMethod) withObject:nil waitUntilDone:NO];
}

- (IBAction)generateNSError:(id)sender {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:@"//invalid/path/somewhere" error:&error];
    if (error) {
        [Bugsnag notifyError:error];
    }
}

- (IBAction)generateSignal:(id)sender {
    Byte *p[10000];
    int allocatedMB = 0;

    while (true) {
        p[allocatedMB] = malloc(1048576);
        memset(p[allocatedMB], 0, 1048576);
        allocatedMB += 1;
        NSLog(@"%d", allocatedMB);
    }
}

- (IBAction)delayedException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"Queuing a non-fatal exception in 5 seconds"];
    [self performSelector:@selector(nonFatalException:) withObject:sender afterDelay:5];
}

- (IBAction)nonFatalException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"generate non-fatal exception"];
    @try {
        // Code that can potentially throw an Exception:
        NSDictionary *actuallyReallyJSON = nil;
        [NSJSONSerialization dataWithJSONObject:actuallyReallyJSON options:0 error:nil];
    }
    @catch (NSException *exception) {
        [Bugsnag notify:exception block:^(BugsnagCrashReport *report) {
            [report addMetadata:@{
                                  @"foo":@"bar"
                                  } toTabWithName:@"extras"];
        }];
    }
}

- (IBAction)objectiveCLockSignal:(id)sender {
    /* Some random data */
    void *cache[] = {
        NULL, NULL, NULL
    };

    void *displayStrings[6] = {
        "This little piggy went to the meerket",
        "This little piggy stayed at home",
        cache,
        "This little piggy had roast beef.",
        "This little piggy had none.",
        "And this little piggy went 'Wee! Wee! Wee!' all the way home",
    };

    /* A corrupted/under-retained/re-used piece of memory */
    struct {
        void *isa;
    } corruptObj;
    corruptObj.isa = displayStrings;

    /* Message an invalid/corrupt object. This will deadlock crash reporters
     * using Objective-C. */
    [(__bridge id)&corruptObj class];
}


static void *enable_threading (void *ctx) {
    return NULL;
}

- (IBAction)pthreadsLockSignal:(id)sender {
    /* We have to use pthread_create() to enable locking in malloc/pthreads/etc -- this
     * would happen by default in any real application, as the standard frameworks
     * (such as dispatch) will trigger similar calls into the pthread APIs. */
    pthread_t thr;
    pthread_create(&thr, NULL, enable_threading, NULL);

    /* This is the actual code that triggers a reproducible deadlock; include this
     * in your own app to test a different crash reporter's behavior.
     *
     * While this is a simple test case to reliably trigger a deadlock, it's not necessary
     * to crash inside of a pthread call to trigger this bug. Any thread sitting inside of
     * pthread() at the time a crash occurs would trigger the same deadlock. */
    pthread_getname_np(pthread_self(), (char *)0x1, 1);
}

- (IBAction)stackOverflow:(id)sender {
    /* A small typo can trigger infinite recursion ... */
    NSArray *resultMessages = [NSMutableArray arrayWithObject: @"Error message!"];
    NSMutableArray *results = [[NSMutableArray alloc] init];

    for (NSObject *result in resultMessages)
        [results addObject: results]; // Whoops!

    NSLog(@"Results: %@", results);
}

- (IBAction)addClientMetadata:(id)sender {
    [Bugsnag addAttribute:@"client!" withValue:@"metadata!" toTabWithName:@"extras"];
}

- (IBAction)addFilteredMetadata:(id)sender {
    [Bugsnag addAttribute:@"filter_me" withValue:@"not_here" toTabWithName:@"extras"];
}

- (IBAction)addMetadataCallback:(id)sender {
    [Bugsnag.configuration addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        [report addMetadata:@{@"callback": @"data!"} toTabWithName:@"extras"];
        return YES;
    }];
}

- (IBAction)addSeverityCallback:(id)sender {
    [Bugsnag.configuration addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        [report setSeverity:BSGSeverityInfo];
        return YES;
    }];
}

- (IBAction)addCustomBreadcrumb:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"This is our custom breadcrumb!"];
}

- (IBAction)addBreadcrumbWithCallback:(id)sender {
    [Bugsnag leaveBreadcrumbWithBlock:^(BugsnagBreadcrumb * breadcrumb) {
        breadcrumb.name = @"Custom breadcrumb name";
        breadcrumb.type = BSGBreadcrumbTypeManual;
        breadcrumb.metadata = @{
            @"metadata": @"here!"
        };
    }];
}

- (IBAction)startNewSession:(id)sender {
    [Bugsnag startSession];
}

- (IBAction)pauseCurrentSession:(id)sender {
    [Bugsnag stopSession];
}

- (IBAction)resumeCurrentSession:(id)sender {
    [Bugsnag resumeSession];
}

@end
