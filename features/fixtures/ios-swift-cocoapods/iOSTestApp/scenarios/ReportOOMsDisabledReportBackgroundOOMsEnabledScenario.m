#import "ReportOOMsDisabledReportBackgroundOOMsEnabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledReportBackgroundOOMsEnabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.enabledErrorTypes &= ~BSGErrorTypesOOMs; // OOM == 0
    [super startBugsnag];
}

- (void)run {
}
@end
