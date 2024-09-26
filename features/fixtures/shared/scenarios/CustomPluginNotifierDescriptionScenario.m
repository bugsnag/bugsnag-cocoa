#import "Scenario.h"
#import "Logging.h"
#import "Bridge_InternalAPI.h"

@interface CustomPluginNotifierDescriptionScenario : Scenario
@end

@interface DescriptionPlugin : NSObject<BugsnagPlugin>

@end

@implementation DescriptionPlugin

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)load:(BugsnagClient *)client {
    id notifier = [Bugsnag client].notifier;
    [notifier setValue:@"2.1.0" forKeyPath:@"version"];
    [notifier setValue:@"Foo Handler Library" forKeyPath:@"name"];
    [notifier setValue:@"https://example.com" forKeyPath:@"url"];
}

- (void)unload {}
@end

@implementation CustomPluginNotifierDescriptionScenario

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
    [self.config addPlugin:[DescriptionPlugin new]];
}

- (void)run {
    __builtin_trap();
}

@end
