#import "ReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.reportBackgroundOOMs = YES;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    [Bugsnag configuration].releaseStage = @"beta";
}
@end
