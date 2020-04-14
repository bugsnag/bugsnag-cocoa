
#import "OOMForegroundScenario.h"

@implementation OOMForegroundScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        NSMutableDictionary *metadata = [report.metaData mutableCopy];
        metadata[@"extra"] = @{ @"shape": @"line" };
        report.metaData = metadata;
        return YES;
    }];
    
    if(![self.eventMode isEqualToString:@"reportOOMsFalse"]) {
        self.config.reportOOMs = true;
    }
    
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    kill(getpid(), SIGKILL);
}
@end
