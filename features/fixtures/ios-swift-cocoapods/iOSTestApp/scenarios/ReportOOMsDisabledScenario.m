
#import "ReportOOMsDisabledScenario.h"
#import <signal.h>

@implementation ReportOOMsDisabledScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.enabledErrorTypes.ooms = false;
    [super startBugsnag];
}

- (void)run {
}
@end
