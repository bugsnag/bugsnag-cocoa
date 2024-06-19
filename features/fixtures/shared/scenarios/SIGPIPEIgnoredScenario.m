//
//  SIGPIPEIgnoredScenario.m
//  iOSTestApp
//
//  Created by Nick Dowell on 14/02/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface SIGPIPEIgnoredScenario : Scenario

@end

@implementation SIGPIPEIgnoredScenario

- (void)configure {
    [super configure];
    sigignore(SIGPIPE);
    self.config.autoTrackSessions = NO;
}

- (void)run {
    int pipefds[2];
    pipe(pipefds);
    close(pipefds[0]);
    write(pipefds[1], "hello\n", 6);
    [Bugsnag startSession];
}

@end
