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

@property Boolean automatedMode;

@end

#pragma mark -

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.apiKey = @"12312312312312312312312312312312";
    self.notifyEndpoint = @"http://localhost:9339/notify";
    self.sessionEndpoint = @"http://localhost:9339/sessions";
    self.automatedMode = true;
    
    if (self.automatedMode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSelector:@selector(startUsingEnvironment) withObject:nil afterDelay:0.1];
        });

    }
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
    BSLog(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);
    
    // Cater for multiple calls to -run
    if (!Scenario.currentScenario) {
        [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
        Scenario.currentScenario.eventMode = self.scenarioMetadata;

        BSLog(@"Starting Bugsnag for scenario: %@", Scenario.currentScenario);
        [Scenario.currentScenario startBugsnag];
    }

    BSLog(@"Will run scenario: %@", Scenario.currentScenario);
    // Using dispatch_async to prevent AppleEvents swallowing exceptions.
    // For more info see https://www.chimehq.com/blog/sad-state-of-exceptions
    // 0.1s delay allows accessibility APIs to finish handling the mouse click and returns control to the tests framework.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BSLog(@"Running scenario: %@", Scenario.currentScenario);
        [Scenario.currentScenario run];
    });
}

- (IBAction)startBugsnag:(id)sender {
    BSLog(@"%s %@", __PRETTY_FUNCTION__, self.scenarioName);

    [Scenario createScenarioNamed:self.scenarioName withConfig:[self configuration]];
    Scenario.currentScenario.eventMode = self.scenarioMetadata;

    BSLog(@"Starting Bugsnag for scenario: %@", Scenario.currentScenario);
    [Scenario.currentScenario startBugsnag];
}

- (IBAction)clearPersistentData:(id)sender {
    BSLog(@"Clearing persistent data");
    [Scenario clearPersistentData];
}

- (IBAction)useDashboardEndpoints:(id)sender {
    self.notifyEndpoint = @"https://notify.bugsnag.com";
    self.sessionEndpoint = @"https://sessions.bugsnag.com";
}

- (IBAction)executeMazeRunnerCommand:(id)sender {
    [Scenario executeMazeRunnerCommand:^(NSString *action, NSString *scenarioName, NSString *eventMode){
        self.scenarioName = scenarioName;
        self.scenarioMetadata = eventMode;
    }];
}

- (void) startUsingEnvironment {
    BSLog(@"Running in Automated mode using environment variables");
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    self.scenarioName = [environment objectForKey:@"BUGSNAG_SCENARIO_NAME"];
    self.scenarioMetadata = [environment objectForKey:@"BUGSNAG_SCENARIO_METADATA"];
    NSString *clearData = (NSString *)[environment objectForKey:@"BUGSNAG_CLEAR_DATA"];
    if ([clearData isEqualToString:@"true"]) {
        [self clearPersistentData:nil];
    }
    NSString *action = (NSString *)[environment objectForKey:@"BUGSNAG_SCENARIO_ACTION"];
    BSLog(@"Received action: %@ for scenario: %@ and metadata: %@", action, self.scenarioName, self.scenarioMetadata);
    if ([action isEqualToString:@"run_scenario"]) {
        [self runScenario:nil];
    } else if ([action isEqualToString:@"start_bugsnag"]) {
        [self startBugsnag:nil];
    }
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
