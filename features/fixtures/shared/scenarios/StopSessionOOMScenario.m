#import "StopSessionOOMScenario.h"

@implementation StopSessionOOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    self.config.enabledErrorTypes = errorTypes;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
    // This test has determinism issues with ordering of payloads and batching of event payloads
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
        [Bugsnag pauseSession];
        kill(getpid(), SIGKILL);
    });
}

@end
