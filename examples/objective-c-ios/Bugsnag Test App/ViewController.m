//
//  ViewController.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "ViewController.h"
#import "OutOfMemoryController.h"
#import "CxxException.h"
#import <Bugsnag/Bugsnag.h>
#import <pthread.h>
#import <stdlib.h>

@interface NSObject (NeverGonnaBeImplemented)

- (void)someRandomMethod;

@end

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
 
 When this low memory state occurs the app will be closed by the operating system and an OOM error report delivered to your Bugsnag dashboard when reopened.
 */
- (IBAction)crashMemoryPressure:(id)sender {
    OutOfMemoryController *controller = [OutOfMemoryController new];
    [self.navigationController pushViewController:controller animated:YES];
}

/**
 This generates an exception that won't be caught by any error handling.  If Bugsnag is set up correctly upon reopening the app the error will be reported to your Bugsnag dashboard.
 */
- (IBAction)crashUncaughtException:(id)sender {
    [self performSelectorOnMainThread:@selector(someRandomMethod) withObject:nil waitUntilDone:NO];
}

/**
 This method captures an error from the app and manually notifies it to your Bugsnag dashboard.  This will happen in real time, and will not require restarting the app.
 */
- (IBAction)generateNSError:(id)sender {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:@"//invalid/path/somewhere" error:&error];
    if (error) {
        [Bugsnag notifyError:error];
    }
}

/**
 This method causes a signal from the operating system to terminate the app.  Upon reopening the app this signal should be notified to your Bugsnag dashboard.
 */
- (IBAction)generateSignal:(id)sender {
    __builtin_trap();
}

/**
 This method causes a low-level exception from the operating system to terminate the app.  Upon reopening the app this signal should be notified to your Bugsnag dashboard.
 */
- (IBAction)generateMachException:(id)sender {
    // This should result in an EXC_BAD_ACCESS mach exception with code = KERN_INVALID_ADDRESS and subcode = 0xDEADBEEF
    void (* ptr)(void) = (void *)0xDEADBEEF;
    ptr();
}

/**
 This method causes a Cxx exception to crash the app.  Upon reopening the app this exception should be notified to your Bugsnag dashboard.
 */
- (IBAction)generateCxxException:(id)sender {
    [[CxxException new] crash];
}

/**
 This method causes a non-fatal exception to be thrown after several seconds, which will be caught and delivered to Bugsnag.
 */
- (IBAction)delayedException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"Queuing a non-fatal exception in 5 seconds"];
    [self performSelector:@selector(nonFatalException:) withObject:sender afterDelay:5];
}

/**
 This method does the same as the above, but immediately.
 In addition it adds some addition metadata using a BugsnagEvent callback.
 This data can be found under the "extras" metadata tab of this exception on your Bugsnag dashboard.
 */
- (IBAction)nonFatalException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"generate non-fatal exception"];
    @try {
        // Code that can potentially throw an Exception:
        NSDictionary *actuallyReallyJSON = nil;
        [NSJSONSerialization dataWithJSONObject:actuallyReallyJSON options:0 error:nil];
    }
    @catch (NSException *exception) {
        [Bugsnag notify:exception block:^BOOL(BugsnagEvent * _Nonnull event) {
            [event addMetadata:@{
            @"foo":@"bar"
            } toSection:@"extras"];
            return YES;
        }];
    }
}

/**
 This method will crash the application through memory corruption.  Upon reopening the app the error will be reported to your Bugsnag dashboard.
 */
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

/**
 This will cause a stackOverflow, delivering the error to the Bugsnag dashboard once the app has restarted.
 */
- (IBAction)stackOverflow:(id)sender {
    /* A small typo can trigger infinite recursion ... */
    NSArray *resultMessages = [NSMutableArray arrayWithObject: @"Error message!"];
    NSMutableArray *results = [[NSMutableArray alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-circular-container"
#pragma clang diagnostic ignored "-Wunused-variable"
    for (NSObject *result in resultMessages)
        [results addObject: results]; // Whoops!
#pragma clang diagnostic pop

    NSLog(@"Results: %@", results);
}

- (IBAction)fatalAppHang:(id)sender {
    [NSThread sleepForTimeInterval:3];
    _exit(1);
}

/**
 This method adds some metadata to your application client, that will be included in all subsequent error reports, and visible on the "extras" tab  on the Bugsnag dashboard.
 */
- (IBAction)addClientMetadata:(id)sender {
    [Bugsnag addMetadata:@"metadata!" withKey:@"client" toSection:@"extras"];
}

/**
 This method adds some metadata that will be redacted on the Bugsnag dashboard.  It will only work if the optional configuration is uncommented in the `AppDelegate.m` file.
 */
- (IBAction)addFilteredMetadata:(id)sender {
    [Bugsnag addMetadata:@"not_here" withKey:@"filter_me"  toSection:@"extras"];
}

/**
 This method clears all metadata in the "extras" tab that would be attached to the error reports.  It won't clear data that hasn't been added yet, like data attached through a callback.
 */
- (IBAction)clearMetaData:(id)sender {
    [Bugsnag clearMetadataFromSection:@"extras"];
}

/**
 This is the simplest example of leaving a custom breadcrumb. This will show up under the "breadcrumbs" tab of your error on the Bugsnag dashboard
 */
- (IBAction)addCustomBreadcrumb:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"This is our custom breadcrumb!"];
}

/**
 This adds a callback to the breadcrumb process, setting a different breadcrumb type if a specific message is present.  It when leaves a slightly more detailed breadcrumb than before, with a message, metadata, and type all specified.
 */
- (IBAction)addBreadcrumbWithCallback:(id)sender {
    [Bugsnag addOnBreadcrumbBlock:^BOOL(BugsnagBreadcrumb * _Nonnull breadcrumb) {
        if ([breadcrumb.message isEqualToString:@"Custom breadcrumb name"]) {
            breadcrumb.type = BSGBreadcrumbTypeProcess;
        }
        return YES;
    }];
    [Bugsnag leaveBreadcrumbWithMessage:@"Custom breadcrumb name" metadata:@{
        @"metadata": @"here!"
    } andType:BSGBreadcrumbTypeManual];
}

/**
 This starts a new session within Bugsnag.  While sessions are generally configured to work automatically, this allows you to define when a session begins.
 */
- (IBAction)startNewSession:(id)sender {
    [Bugsnag startSession];
}

/**
 This pauses the current session.  If an error occurs when a session is paused it will not be included in the session statistics for the project.
 */
- (IBAction)pauseCurrentSession:(id)sender {
    [Bugsnag pauseSession];
}

/**
 This allows you to resume the previous session, keeping a record of any errors that previously occurred within a single session intact.
 */
- (IBAction)resumeCurrentSession:(id)sender {
    [Bugsnag resumeSession];
}

/**
 This sets a user on the client, similar to setting one on the configuration.  It will also set the user in a session payload.
 */
- (IBAction)setUser:(id)sender {
    [Bugsnag setUser:@"TestUser" withEmail:@"TestUser@UserTesting.co" andName:@"Test Userson"];
}

@end
