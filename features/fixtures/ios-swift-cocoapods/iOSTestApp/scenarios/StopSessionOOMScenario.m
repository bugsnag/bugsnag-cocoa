#import "StopSessionOOMScenario.h"

@implementation StopSessionOOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
    [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
    [Bugsnag pauseSession];
}

@end
