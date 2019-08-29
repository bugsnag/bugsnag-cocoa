#import "ReportOOMsDisabledReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.reportOOMs = NO;
    self.config.reportBackgroundOOMs = YES;
    [super startBugsnag];
}

- (void)run {
}
@end
