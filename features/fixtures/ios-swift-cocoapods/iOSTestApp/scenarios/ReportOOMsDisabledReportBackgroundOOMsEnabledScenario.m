#import "ReportOOMsDisabledReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.reportOOMs = NO;
    [super startBugsnag];
}

- (void)run {
}
@end
