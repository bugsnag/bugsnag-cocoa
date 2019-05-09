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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        raise(SIGKILL);
    });
}
@end
