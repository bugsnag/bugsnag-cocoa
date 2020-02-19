#import "ReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
}
@end
