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

@property (nonatomic,strong) FixtureConfig *fixtureConfig;
@property (nonatomic,strong) Fixture *fixture;

@end

#pragma mark -

static NSString *defaultAPIKey = @"12312312312312312312312312312312";
static NSString *defaultMazeRunnerURLString = @"http://localhost:9339";

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.fixtureConfig = [[FixtureConfig alloc] initWithApiKey:defaultAPIKey
                                         mazeRunnerBaseAddress:[NSURL URLWithString:defaultMazeRunnerURLString]];
    self.fixture = [[Fixture alloc] initWithDefaultMazeRunnerURL:self.fixtureConfig.mazeRunnerURL
                                         shouldLoadMazeRunnerURL:NO];
    self.apiKey = self.fixtureConfig.apiKey;
    self.notifyEndpoint = self.fixtureConfig.notifyURL.absoluteString;
    self.sessionEndpoint = self.fixtureConfig.sessionsURL.absoluteString;
}

- (void)startFixture {
    [self.fixture start];
}

- (IBAction)runScenario:(id)sender {
    logDebug(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);
    
    [self.fixture setApiKeyWithApiKey:self.apiKey];
    [self.fixture setNotifyEndpointWithEndpoint:self.notifyEndpoint];
    [self.fixture setSessionEndpointWithEndpoint:self.sessionEndpoint];
    NSString *scenarioName = self.scenarioName;
    NSArray<NSString *> *args = @[];
    if (self.scenarioMetadata != nil) {
        args = @[self.scenarioMetadata];
    }

    // Using dispatch_async to prevent AppleEvents swallowing exceptions.
    // For more info see https://www.chimehq.com/blog/sad-state-of-exceptions
    // 0.1s delay allows accessibility APIs to finish handling the mouse click and returns control to the tests framework.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        logInfo(@"Running scenario: %@", scenarioName);
        [self.fixture runScenarioWithScenarioName:scenarioName args:args launchCount:1 completion:^{}];
    });
}

- (IBAction)startBugsnag:(id)sender {
    logDebug(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);

    NSString *scenarioName = self.scenarioName;
    NSArray<NSString *> *args = @[];
    if (self.scenarioMetadata != nil) {
        args = @[self.scenarioMetadata];
    }

    [self.fixture startBugsnagForScenarioWithScenarioName:scenarioName args:args launchCount:1 completion:^{}];
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
