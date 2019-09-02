
#import "OOMDeviceScenario.h"
#import <signal.h>

@implementation OOMDeviceScenario

- (void)startBugsnag {
    self.config.shouldAutoCaptureSessions = NO;
    self.config.releaseStage = @"alpha";
    [self.config addBeforeSendBlock:^bool(NSDictionary * _Nonnull rawEventData, BugsnagCrashReport * _Nonnull report) {
        NSMutableDictionary *metadata = [report.metaData mutableCopy];
        metadata[@"extra"] = @{ @"shape": @"line" };
        report.metaData = metadata;
        return YES;
    }];
    [super startBugsnag];
}

- (void)run {
    NSMutableArray *stringArray = [[NSMutableArray alloc] init];
    dispatch_queue_t queue = dispatch_queue_create("js queue", NULL);
    dispatch_async(queue, ^{
        for (int i = 0; i < 1000 * 1024; i++) {
            dispatch_async(dispatch_get_main_queue(), ^{
                for (int j = 0; j < 1000; j++) {
                    [stringArray addObject:@"LLANFAIRPWLLGWYNGYLLGOGERYCHWYRNDROBWLLLLANTYSILIOGOGOGOCH"];
                }
                NSLog(@"Loaded %d items", i * 1000);
            });
        }
    });
}
@end
