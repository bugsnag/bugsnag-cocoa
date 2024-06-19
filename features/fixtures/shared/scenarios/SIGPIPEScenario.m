//
//  SIGPIPEScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface SIGPIPEScenario : Scenario
@end

@implementation SIGPIPEScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    int pipefds[2];
    pipe(pipefds);
    close(pipefds[0]);
    write(pipefds[1], "hello\n", 6);
}

@end
