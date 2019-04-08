
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        raise(SIGKILL);
    });
}
@end
