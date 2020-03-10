#import "CustomPluginNotifierDescriptionScenario.h"
#import <Bugsnag/BugsnagPlugin.h>

@interface Bugsnag()
+ (id)client;
+ (void)registerPlugin:(id<BugsnagPlugin>)plugin;
@end

@interface DescriptionPlugin : NSObject<BugsnagPlugin>
@property (nonatomic, getter=isStarted) BOOL started;
@end

@implementation DescriptionPlugin

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)start {
    id notifier = [Bugsnag client];
    NSDictionary *newDetails = @{
        @"version": @"2.1.0",
        @"name": @"Foo Handler Library",
        @"url": @"https://example.com"
    };
    [notifier setValue:newDetails forKey:@"details"];
    self.started = YES;
}


@end

@implementation CustomPluginNotifierDescriptionScenario

- (void)startBugsnag {
    [Bugsnag registerPlugin:[DescriptionPlugin new]];
    self.config.autoTrackSessions = NO;
    [super startBugsnag];
}

- (void)run {
    __builtin_trap();
}

@end
