#import "ResumeSessionOOMScenario.h"

@implementation ResumeSessionOOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag startSession];
    [Bugsnag notify:[NSException exceptionWithName:@"foo" reason:nil userInfo:nil]];
    [Bugsnag stopSession];
    [Bugsnag resumeSession];
}

@end
