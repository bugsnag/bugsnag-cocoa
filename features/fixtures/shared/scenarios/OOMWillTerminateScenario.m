
#import "OOMWillTerminateScenario.h"

#import <signal.h>

@implementation OOMWillTerminateScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
}
@end
