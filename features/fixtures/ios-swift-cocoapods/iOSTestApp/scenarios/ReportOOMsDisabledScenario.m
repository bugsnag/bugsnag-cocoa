
#import "ReportOOMsDisabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.enabledErrorTypes &= ~BSGErrorTypesOOMs; // OOM == 0
    [super startBugsnag];
}

- (void)run {
}
@end
