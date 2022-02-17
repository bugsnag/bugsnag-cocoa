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
@property NSString *commandEndpoint;
@property NSString *scenarioCommandName;
@property NSString *scenarioCommandMetadata;

@end

#pragma mark -

@implementation MainWindowController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.apiKey = @"12312312312312312312312312312312";
    self.notifyEndpoint = @"http://localhost:9339/notify";
    self.sessionEndpoint = @"http://localhost:9339/sessions";
    self.commandEndpoint = @"http://localhost:9339/command";
    self.scenarioCommandName = @"";
    self.scenarioCommandMetadata = @"";
    self.automatedMode = true;
    
    if (self.automatedMode) {
        [self startUsingCommand];
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
    NSString *scenario;
    NSString *metadata;
    if (self.automatedMode) {
        scenario = self.scenarioCommandName;
        metadata = self.scenarioCommandMetadata;
    } else {
        scenario = self.scenarioName;
        metadata = self.scenarioMetadata;
    }
    BSLog(@"%s %@", __PRETTY_FUNCTION__, scenario);
    
    // Cater for multiple calls to -run
    if (!Scenario.currentScenario) {
        [Scenario createScenarioNamed:scenario withConfig:[self configuration]];
        Scenario.currentScenario.eventMode = metadata;

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
    NSString *scenario;
    NSString *metadata;
    if (self.automatedMode) {
        scenario = self.scenarioCommandName;
        metadata = self.scenarioCommandMetadata;
    } else {
        scenario = self.scenarioName;
        metadata = self.scenarioMetadata;
    }
    BSLog(@"%s %@", __PRETTY_FUNCTION__, scenario);

    [Scenario createScenarioNamed:scenario withConfig:[self configuration]];
    Scenario.currentScenario.eventMode = metadata;

    BSLog(@"Starting Bugsnag for scenario: %@", Scenario.currentScenario);
    [Scenario.currentScenario startBugsnag];
}

- (IBAction)clearPersistentData:(id)sender {
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

- (void) startUsingCommand {
    NSLog(@"Running in Automated mode, contacting %@ for command", self.commandEndpoint);
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:self.commandEndpoint]];
    [urlRequest setHTTPMethod:@"GET"];

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
      if(error == nil)
      {
        NSError *parseError = nil;
        NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
          self.scenarioCommandName = responseDictionary[@"scenario_name"];
          self.scenarioCommandMetadata = responseDictionary[@"scenario_mode"];
          NSLog(@"Received command: %@", responseDictionary);
          if (responseDictionary[@"reset_data"]) {
              [self clearPersistentData:nil];
          }
          if ([@"run_scenario" isEqualToString:responseDictionary[@"action"]]) {
              [self runScenario:nil];
          } else if ([@"start_bugsnag" isEqualToString:responseDictionary[@"action"]]) {
              [self startBugsnag:nil];
          } else {
              BSLog(@"Cannot run scenario due to invalid action: %@", responseDictionary[@"action"]);
          }
      }
      else
      {
        NSLog(@"Error: %@", error);
      }
    }];
    [dataTask resume];
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
