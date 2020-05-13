
#import "OOMForegroundScenario.h"

@implementation OOMForegroundScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addOnSendErrorBlock:^BOOL(BugsnagEvent * _Nonnull event) {
        [event addMetadata:@{ @"shape": @"line" } toSection:@"extra"];
        return YES;
    }];
    
    if(![self.eventMode isEqualToString:@"reportOOMsFalse"]) {
        BugsnagErrorTypes *errorTypes = [BugsnagErrorTypes new];
        self.config.enabledErrorTypes = errorTypes;
    }
    
    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Crumb left before crash"];
    kill(getpid(), SIGKILL);
}
@end
