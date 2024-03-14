//
//  MainWindowController.m
//  macOSTestApp
//
//  Created by Nick Dowell on 29/10/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "MainWindowController.h"

#import "Scenario.h"
#import "Logging.h"
#import "macOSTestApp-Swift.h"

#import <Bugsnag/Bugsnag.h>

@interface MainWindowController ()

// These properties are used with Cocoa Bindings
@property (copy) NSString *apiKey;
@property (copy) NSString *notifyEndpoint;
@property (copy) NSString *scenarioMetadata;
@property (copy) NSString *scenarioName;
@property (copy) NSString *sessionEndpoint;
@property (nonatomic,strong) Fixture *fixture;

@end

#pragma mark -

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.apiKey = @"12312312312312312312312312312312";
    self.notifyEndpoint = @"http://localhost:9339/notify";
    self.sessionEndpoint = @"http://localhost:9339/sessions";
    self.fixture = [[Fixture alloc] init];
}

- (BugsnagConfiguration *)configuration {
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:self.apiKey];
    if (self.notifyEndpoint) {
        configuration.endpoints.notify = self.notifyEndpoint;
    }
    if (self.sessionEndpoint) {
        configuration.endpoints.sessions = self.sessionEndpoint;
    }
    return configuration;
}

- (IBAction)runScenario:(id)sender {
    logDebug(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);
    
    [self.fixture setApiKeyWithApiKey:self.apiKey];
    [self.fixture setNotifyEndpointWithEndpoint:self.notifyEndpoint];
    [self.fixture setSessionEndpointWithEndpoint:self.sessionEndpoint];
    NSString *scenarioName = self.scenarioName;
    NSArray<NSString *> *args = @[self.scenarioMetadata];
    
    // Using dispatch_async to prevent AppleEvents swallowing exceptions.
    // For more info see https://www.chimehq.com/blog/sad-state-of-exceptions
    // 0.1s delay allows accessibility APIs to finish handling the mouse click and returns control to the tests framework.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        logInfo(@"Running scenario: %@", scenarioName);
        [self.fixture runScenarioWithScenarioName:scenarioName args:args completion:^{}];
    });
}

- (IBAction)startBugsnag:(id)sender {
    logDebug(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);

    NSString *scenarioName = self.scenarioName;
    NSArray<NSString *> *args = @[self.scenarioMetadata];

    [self.fixture startBugsnagForScenarioWithScenarioName:scenarioName args:args completion:^{}];
}

- (IBAction)clearPersistentData:(id)sender {
    logInfo(@"Clearing persistent data");
    [self.fixture clearPersistentData];
}

- (IBAction)useDashboardEndpoints:(id)sender {
    self.notifyEndpoint = @"https://notify.bugsnag.com";
    self.sessionEndpoint = @"https://sessions.bugsnag.com";
}

- (IBAction)executeMazeRunnerCommand:(id)sender {
    NSLog(@"WARNING: executeMazeRunnerCommand has been DISABLED.");
//    Scenario.baseMazeAddress = @"http://localhost:9339";
//    [Scenario executeMazeRunnerCommand:^(NSString *scenarioName, NSString *eventMode){
//        self.scenarioName = scenarioName;
//        self.scenarioMetadata = eventMode;
//    }];
}

@end
