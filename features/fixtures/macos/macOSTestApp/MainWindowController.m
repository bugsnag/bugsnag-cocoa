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

static void BSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2) NS_NO_TAIL_CALL;


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
    BSLog(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);

    if (!self.scenario) {
        self.scenario = [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
        self.scenario.eventMode = self.scenarioMetadata;

        BSLog(@"Starting Bugsnag for scenario: %@", self.scenario);
        [self.scenario startBugsnag];
    }

    BSLog(@"Will run scenario: %@", self.scenario);
    // Using dispatch_async to prevent AppleEvents swallowing exceptions.
    // For more info see https://www.chimehq.com/blog/sad-state-of-exceptions
    // 0.1s delay allows accessibility APIs to finish handling the mouse click and returns control to the tests framework.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BSLog(@"Running scenario: %@", self.scenario);
        [self.scenario run];
    });
}

- (IBAction)startBugsnag:(id)sender {
    BSLog(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);

    self.scenario = [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
    self.scenario.eventMode = self.scenarioMetadata;

    BSLog(@"Starting Bugsnag for scenario: %@", self.scenario);
    [self.scenario startBugsnag];
}

- (IBAction)clearPersistentData:(id)sender {
    [Scenario clearPersistentData];
}

- (IBAction)useDashboardEndpoints:(id)sender {
    self.notifyEndpoint = @"https://notify.bugsnag.com";
    self.sessionEndpoint = @"https://sessions.bugsnag.com";
}

@end


static void BSLog(NSString *format, ...) {
    va_list vl;
    va_start(vl, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:vl];
    NSLog(@"%@", message);
    kslog(message.UTF8String);
    va_end(vl);
}
