//
//  SIGPIPEIgnoredScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 14/02/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface SIGPIPEIgnoredScenario : Scenario

@end

@implementation SIGPIPEIgnoredScenario

- (void)startBugsnag {
    sigignore(SIGPIPE);
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    int pipefds[2];
    pipe(pipefds);
    close(pipefds[0]);
    write(pipefds[1], "hello\n", 6);
    [Bugsnag startSession];
}

@end
