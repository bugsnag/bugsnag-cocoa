#import "ConfigChangesAfterStartScenarios.h"

@implementation TurnOnCrashDetectionAfterStartScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.autoNotify = NO;
    [super startBugsnag];
}

- (void)run {
    self.config.autoNotify = YES;
    __builtin_trap();
}
@end


@implementation TurnOffCrashDetectionAfterStartScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    [super startBugsnag];
}

- (void)run {
    self.config.autoNotify = NO;
    __builtin_trap();
}

@end
