#import "ConfigChangesAfterStartScenarios.h"

@implementation TurnOnCrashDetectionAfterStartScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.autoDetectErrors = NO;
    [super startBugsnag];
}

- (void)run {
    self.config.autoDetectErrors = YES;
    __builtin_trap();
}
@end


@implementation TurnOffCrashDetectionAfterStartScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    [super startBugsnag];
}

- (void)run {
    self.config.autoDetectErrors = NO;
    __builtin_trap();
}

@end
