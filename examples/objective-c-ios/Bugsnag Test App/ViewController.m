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
    Byte *p[10000];
    int allocatedMB = 0;

    while (true) {
        p[allocatedMB] = malloc(1048576);
        memset(p[allocatedMB], 0, 1048576);
        allocatedMB += 1;
        NSLog(@"%d", allocatedMB);
    }
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


static void *enable_threading (void *ctx) {
    return NULL;
}

/**
 This will cause a deadlock error, delivering to the Bugsnag dashboard after the app has restarted.
 */
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

/**
 This will cause a stackOverflow, delivering the error to the Bugsnag dashboard once the app has restarted.
 */
- (IBAction)stackOverflow:(id)sender {
    /* A small typo can trigger infinite recursion ... */
    NSArray *resultMessages = [NSMutableArray arrayWithObject: @"Error message!"];
    NSMutableArray *results = [[NSMutableArray alloc] init];

    for (NSObject *result in resultMessages)
        [results addObject: results]; // Whoops!

    NSLog(@"Results: %@", results);
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
 This method adds a callback that will trigger whenever an error is triggered.  In this case some extra information is added to the "extras" tab, and the full range of callback functionality can be found at https://docs.bugsnag.com/platforms/ios/customizing-error-reports/
 */
- (IBAction)addMetadataCallback:(id)sender {
    [Bugsnag addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        [event addMetadata:@{@"callback": @"data!"} toSection:@"extras"];
        return YES;
    }];
}

/**
 As above, this method adds a callback to trigger when an error occurs.  However this one will set the Severity of the error to "Info" which will be reflected in the errors appearance in your Bugsnag dashboard.
 */
- (IBAction)addSeverityCallback:(id)sender {
    [Bugsnag addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        [event setSeverity:BSGSeverityInfo];
        return YES;
    }];
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
