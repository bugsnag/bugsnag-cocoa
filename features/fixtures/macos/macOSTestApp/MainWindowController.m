//
//  MainWindowController.m
//  macOSTestApp
//
//  Created by Nick Dowell on 29/10/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "MainWindowController.h"

#import "Scenario.h"

#import <Bugsnag/Bugsnag.h>


@interface MainWindowController ()

// These properties are used with Cocoa Bindings
@property (copy) NSString *apiKey;
@property (copy) NSString *notifyEndpoint;
@property (copy) NSString *scenarioMetadata;
@property (copy) NSString *scenarioName;
@property (copy) NSString *sessionEndpoint;

@property Scenario *scenario;

@end

#pragma mark -

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.apiKey = @"12312312312312312312312312312312";
    self.notifyEndpoint = @"http://bs-local.com:9339/notify";
    self.sessionEndpoint = @"http://bs-local.com:9339/sessions";
}

- (BugsnagConfiguration *)configuration {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:self.apiKey];
    if (self.notifyEndpoint) {
        configuration.endpoints.notify = self.notifyEndpoint;
    }
    if (self.sessionEndpoint) {
        configuration.endpoints.sessions = self.sessionEndpoint;
    }
    configuration.enabledErrorTypes.ooms = NO;
    return configuration;
}

- (IBAction)runScenario:(id)sender {
    if (!self.scenario) {
        self.scenario = [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
        self.scenario.eventMode = self.scenarioMetadata;

        NSLog(@"Starting Bugsnag for scenario: %@", self.scenario);
        [self.scenario startBugsnag];
    }

    NSLog(@"Will run scenario: %@", self.scenario);
    // Using dispatch_async to prevent AppleEvents swallowing exceptions.
    // For more info see https://www.chimehq.com/blog/sad-state-of-exceptions
    // 0.1s delay allows accessibility APIs to finish handling the mouse click and returns control to the tests framework.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Running scenario: %@", self.scenario);
        [self.scenario run];
    });
}

- (IBAction)startBugsnag:(id)sender {
    self.scenario = [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
    self.scenario.eventMode = self.scenarioMetadata;

    NSLog(@"Starting Bugsnag for scenario: %@", self.scenario);
    [self.scenario startBugsnag];
}

- (IBAction)clearPersistentData:(id)sender {
    NSLog(@"Clear persistent data");
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSArray<NSString *> *entries = @[
        @"bsg_kvstore",
        @"bsgkv",
        @"bugsnag",
        @"bugsnag_breadcrumbs.json",
        @"bugsnag_handled_crash.txt",
        @"KSCrash",
        @"KSCrashReports"];
    for (NSString *entry in entries) {
        NSString *path = [cachesDir stringByAppendingPathComponent:entry];
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:path error:&error]) {
            if (![error.domain isEqualTo:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
                NSLog(@"%@", error);
            }
        }
    }
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *rootDir = [appSupportDir stringByAppendingPathComponent:@"com.bugsnag.Bugsnag"];
    NSError *error = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:rootDir error:&error]) {
        if (![error.domain isEqualTo:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
            NSLog(@"%@", error);
        }
    }
}

- (IBAction)useDashboardEndpoints:(id)sender {
    self.notifyEndpoint = @"https://notify.bugsnag.com";
    self.sessionEndpoint = @"https://sessions.bugsnag.com";
}

@end
