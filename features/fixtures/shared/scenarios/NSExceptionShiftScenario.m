#import "Scenario.h"
#import "Logging.h"

@interface NSExceptionShiftScenario : Scenario
@end

@implementation NSExceptionShiftScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    [self causeAnException];
}

- (void)causeAnException {
    @try {
        @throw [NSException exceptionWithName:@"Tertiary failure"
                                       reason:@"invalid invariant"
                                     userInfo:nil];
    } @catch (NSException *exception) {
        [self shouldNotBeInStacktrace:exception];
    }
}

- (void)shouldNotBeInStacktrace:(NSException *)exception {
    [Bugsnag notify:exception];
}

@end
