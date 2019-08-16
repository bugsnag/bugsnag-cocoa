
#import "ReportOOMsDisabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.reportOOMs = NO;
    [super startBugsnag];
}

- (void)run {
}
@end
