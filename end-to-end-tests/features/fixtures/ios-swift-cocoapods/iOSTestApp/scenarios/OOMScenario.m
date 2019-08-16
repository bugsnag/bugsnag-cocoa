
#import "OOMScenario.h"
#import <signal.h>

@implementation OOMScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.releaseStage = @"alpha";
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    [Bugsnag configuration].releaseStage = @"beta";
}
@end
