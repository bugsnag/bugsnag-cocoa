#import "NSExceptionShiftScenario.h"
#import <Bugsnag/Bugsnag.h>

@implementation NSExceptionShiftScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
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
