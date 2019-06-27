#import "SessionOOMScenario.h"
#import <signal.h>

@implementation SessionOOMScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
    [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
}

@end
