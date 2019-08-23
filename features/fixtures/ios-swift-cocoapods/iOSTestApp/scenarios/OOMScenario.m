
#import "OOMScenario.h"
#import <signal.h>

@implementation OOMScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        NSMutableDictionary *metadata = [report.metaData mutableCopy];
        metadata[@"extra"] = @{ @"shape": @"line" };
        report.metaData = metadata;
        return YES;
    }];
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    [Bugsnag configuration].releaseStage = @"beta";
}
@end
