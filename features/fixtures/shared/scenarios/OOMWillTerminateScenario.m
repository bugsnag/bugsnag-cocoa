
#import "Scenario.h"
#import "Logging.h"

#import <signal.h>

@interface OOMWillTerminateScenario : Scenario
@end

@implementation OOMWillTerminateScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

- (void)run {
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
}
@end
