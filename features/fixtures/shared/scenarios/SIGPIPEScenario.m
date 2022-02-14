//
//  SIGPIPEScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "SIGPIPEScenario.h"

@implementation SIGPIPEScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    int pipefds[2];
    pipe(pipefds);
    close(pipefds[0]);
    write(pipefds[1], "hello\n", 6);
}

@end
