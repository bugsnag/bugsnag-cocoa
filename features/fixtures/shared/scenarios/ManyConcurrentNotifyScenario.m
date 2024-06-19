#import "Scenario.h"
#import "Logging.h"

@interface ManyConcurrentNotifyScenario : Scenario
@property (nonatomic) dispatch_queue_t queue1;
@property (nonatomic) dispatch_queue_t queue2;
@end

@interface FooError : NSError
@end
@implementation FooError
@end

@implementation ManyConcurrentNotifyScenario

- (instancetype)initWithFixtureConfig:(FixtureConfig *)config args:( NSArray<NSString *> * _Nonnull )args launchCount:(NSInteger)launchCount {
    if (self = [super initWithFixtureConfig:config args:args launchCount:launchCount]) {
        _queue1 = dispatch_queue_create("Log Queue 1", DISPATCH_QUEUE_CONCURRENT);
        _queue2 = dispatch_queue_create("Log Queue 2", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)run {
    for (int i = 0; i < 4; i++) {
        NSString *message = [NSString stringWithFormat:@"Err %ld", (long)i];
        [self logError:[FooError errorWithDomain:@"com.example"
                                            code:401 + i
                                        userInfo:@{NSLocalizedDescriptionKey: message}]];
    }
}

- (void)logError:(NSError *)error {
    dispatch_async(self.queue1, ^{
        [Bugsnag notifyError:error];
    });
    dispatch_async(self.queue2, ^{
        [Bugsnag notifyError:error];
    });
}

- (void)configure {
    [super configure];
    self.config.autoTrackSessions = NO;
}

@end
