
#import "ReportOOMsDisabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.reportOOMs = NO;
    [super startBugsnag];
}

- (void)run {
}
@end
