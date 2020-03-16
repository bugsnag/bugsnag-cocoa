
#import "OOMScenario.h"
#import <signal.h>

@implementation OOMScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addOnSendBlock:^bool(BugsnagEvent * _Nonnull report) {
        NSMutableDictionary *metadata = [report.metadata mutableCopy];
        metadata[@"extra"] = @{ @"shape": @"line" };
        report.metadata = metadata;
        return YES;
    }];
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
}
@end
