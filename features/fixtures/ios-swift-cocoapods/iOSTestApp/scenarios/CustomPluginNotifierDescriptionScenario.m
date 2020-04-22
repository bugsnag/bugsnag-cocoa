#import "CustomPluginNotifierDescriptionScenario.h"
#import <Bugsnag/Bugsnag.h>

@interface DescriptionPlugin : NSObject<BugsnagPlugin>

@end

@implementation DescriptionPlugin

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)load:(BugsnagClient *)client {
    NSDictionary *newDetails = @{
        @"version": @"2.1.0",
        @"name": @"Foo Handler Library",
        @"url": @"https://example.com"
    };
    [client setValue:newDetails forKey:@"details"];
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
