#import "Scenario.h"
#import "Logging.h"

@interface ResumeSessionOOMScenario : Scenario
@end

@implementation ResumeSessionOOMScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
    BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
    self.config.enabledErrorTypes = errorTypes;
}

- (void)run {
    [Bugsnag startSession];
    // This test has determinism issues with ordering of payloads and batching of event payloads
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
        [Bugsnag pauseSession];
        [Bugsnag resumeSession];
        kill(getpid(), SIGKILL);
    });
}

@end
