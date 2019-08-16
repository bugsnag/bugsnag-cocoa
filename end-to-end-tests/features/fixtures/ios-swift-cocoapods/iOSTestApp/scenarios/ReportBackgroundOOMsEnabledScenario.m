#import "ReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.reportBackgroundOOMs = YES;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    [Bugsnag configuration].releaseStage = @"beta";
}
@end
