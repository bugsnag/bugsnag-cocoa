#import "MarkUnhandledHandledScenario.h"
#import "Logging.h"
#import <Bugsnag/Bugsnag.h>

@interface ObjCExceptionFeatureFlagsScenario: Scenario
@end

@implementation ObjCExceptionFeatureFlagsScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run  __attribute__((noreturn)) {
    [Bugsnag addFeatureFlagWithName:@"Feature Flag1" variant: @"Variant1"];
    [Bugsnag addFeatureFlagWithName:@"Feature Flag2" variant: @"Variant2"];
    [Bugsnag addFeatureFlagWithName:@"Feature Flag3" variant: @"Variant3"];
    [Bugsnag addFeatureFlagWithName:@"Feature Flag4"];
    [Bugsnag clearFeatureFlagWithName:@"Feature Flag2"];
    @throw [NSException exceptionWithName:NSGenericException reason:@"An uncaught exception"
                                 userInfo:@{NSLocalizedDescriptionKey: @""}];
}

@end
