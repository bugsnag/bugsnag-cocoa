//
//  ViewController.m
//  Bugsnag Test App
//
//  Created by Simon Maynard on 1/18/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "ViewController.h"
#import "BigHonkinWebViewController.h"
#import "Bugsnag.h"
#import <pthread.h>
#import <stdlib.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [Bugsnag leaveBreadcrumbWithMessage:@"Loaded iOS Objective-C test app"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [Bugsnag leaveBreadcrumbWithMessage:@"Received memory warning"];
}

- (IBAction)generateOOM:(id)sender {
    BigHonkinWebViewController *controller = [BigHonkinWebViewController new];
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)generateException:(id)sender {
    [Bugsnag leaveBreadcrumbWithMessage:@"Generating exception by non-existent selector"];
    [self performSelectorOnMainThread:@selector(someRandomMethod) withObject:nil waitUntilDone:NO];
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
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject: data forKey: @"data"];

    [Bugsnag notify:[NSException exceptionWithName:@"wat" reason:nil userInfo:nil] block:^(BugsnagCrashReport * _Nonnull report) {
        report.metaData = @{@"tab": @{@"user": @"rar\"watrar"}};
    }];
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

- (IBAction)checkEventLoopSpin:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"APPLICATION CODE IS RUNNING - Crash reporter is spinning runloop");
    });
    raise(SIGSEGV);
}
@end
