#import "ResumeSessionOOMScenario.h"

@implementation ResumeSessionOOMScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
    [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
    [Bugsnag stopSession];
    [Bugsnag resumeSession];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        raise(SIGKILL);
    });
}

@end
