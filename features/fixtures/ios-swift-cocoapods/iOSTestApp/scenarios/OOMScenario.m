#import "OOMScenario.h"
#import <signal.h>

@implementation OOMScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        [event addMetadata:@{ @"shape": @"line" } toSection:@"extra"];
        return YES;
    }];
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
}
@end
