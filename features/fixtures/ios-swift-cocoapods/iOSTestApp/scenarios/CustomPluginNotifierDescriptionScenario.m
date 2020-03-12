#import "CustomPluginNotifierDescriptionScenario.h"
#import <Bugsnag/BugsnagPlugin.h>

@interface Bugsnag()
+ (id)client;
@end

@interface DescriptionPlugin : NSObject<BugsnagPlugin>

@end

@implementation DescriptionPlugin

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)load {
    id notifier = [Bugsnag client];
    NSDictionary *newDetails = @{
        @"version": @"2.1.0",
        @"name": @"Foo Handler Library",
        @"url": @"https://example.com"
    };
    [notifier setValue:newDetails forKey:@"details"];
}

- (void)unload {}
@end

@implementation CustomPluginNotifierDescriptionScenario

- (void)startBugsnag {
    [self.config addPlugin:[DescriptionPlugin new]];
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    __builtin_trap();
}

@end
