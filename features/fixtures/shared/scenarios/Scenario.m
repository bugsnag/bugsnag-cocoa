//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//
#import "Scenario.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS
#define SWIFT_MODULE "iOSTestApp"
#elif TARGET_OS_OSX
#define SWIFT_MODULE "macOSTestApp"
#elif TARGET_OS_WATCH
#import "watchos_maze_host.h"
#define SWIFT_MODULE "watchOSTestApp_WatchKit_Extension"
#else
#error Unsupported TARGET_OS
#endif

extern bool bsg_kslog_setLogFilename(const char *filename, bool overwrite);

extern void bsg_i_kslog_logCBasic(const char *fmt, ...) __printflike(1, 2);

void kslog(const char *message) {
    bsg_i_kslog_logCBasic("%s", message);
}

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer) {
    writer->addBooleanElement(writer, "unhandled", false);
}

// MARK: -

static Scenario *theScenario;
static NSString *theBaseMazeAddress;

#if !TARGET_OS_WATCH
static char ksLogPath[PATH_MAX];
#endif

@implementation Scenario {
    dispatch_block_t _onEventDelivery;
    dispatch_block_t _onSessionDelivery;
}

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:nil usingBlock:^(NSNotification *notification) {
        for (NSString *prefix in @[@"NSAutomaticFocusRingChanged",
                                   @"NSBundleDidLoadNotification",
                                   @"NSMenu",
                                   @"NSTextStorage",
                                   @"NSTextView",
                                   @"NSThreadWillExitNotification",
                                   @"NSUndoManagerCheckpointNotification",
                                   @"NSViewDidUpdateTrackingAreasNotification",
                                   @"NSViewFrameDidChangeNotification",
                                   @"UIScreenBrightnessDidChangeNotification",
                                   @"_"]) {
            if ([notification.name hasPrefix:prefix]) {
                return;
            }
        }
#if TARGET_OS_OSX
        if ([notification.name hasSuffix:@"UpdateNotification"]) {
            return;
        }
#endif
        NSLog(@"%@", notification.name);
    }];
}

+ (Scenario *)createScenarioNamed:(NSString *)className withConfig:(BugsnagConfiguration *)config {
    Class class = NSClassFromString(className) ?:
    NSClassFromString([@SWIFT_MODULE "." stringByAppendingString:className]);

    if (!class) {
        [NSException raise:NSInvalidArgumentException format:@"Failed to find scenario class named %@", className];
    }

    return (theScenario = [(Scenario *)[class alloc] initWithConfig:config]);
}

+ (Scenario *)currentScenario {
    return theScenario;
}

+ (NSString *)baseMazeAddress {
    return theBaseMazeAddress;
}

+ (void)setBaseMazeAddress:(NSString *)baseMazeAddress {
    theBaseMazeAddress = baseMazeAddress;
}

- (instancetype)initWithConfig:(BugsnagConfiguration *)config {
    if (self = [super init]) {
        if (config) {
            _config = config;
        } else {
            _config = [[BugsnagConfiguration alloc] initWithApiKey:@"12312312312312312312312312312312"];
            _config.endpoints.notify = [NSString stringWithFormat:@"%@/notify", theBaseMazeAddress];
            _config.endpoints.sessions = [NSString stringWithFormat:@"%@/sessions", theBaseMazeAddress];
        }
#if !TARGET_OS_WATCH
        _config.enabledErrorTypes.ooms = NO;
#endif
    }
    return self;
}

- (void)run {
    // Must be implemented by all subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)startBugsnag {
    [self performBlockAndReportDuration:^{
        [Bugsnag startWithConfiguration:self.config];
    } measurement:@"start"];
}

- (void)didEnterBackgroundNotification {
}

- (void)performBlockAndWaitForEventDelivery:(dispatch_block_t)block {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    _onEventDelivery = ^{
        dispatch_semaphore_signal(semaphore);
    };
    block();
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)performBlockAndWaitForSessionDelivery:(dispatch_block_t)block NS_SWIFT_NAME(performBlockAndWaitForSessionDelivery(_:)) {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    _onSessionDelivery = ^{
        dispatch_semaphore_signal(semaphore);
    };
    block();
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

- (void)performBlockAndReportDuration:(dispatch_block_t)block measurement:(NSString *)measurement {
    NSDate *startDate = [NSDate new];
    block();
    NSDate *endDate = [NSDate new];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger duration = [[calendar components:NSCalendarUnitNanosecond fromDate:startDate toDate:endDate options: 0] nanosecond];
    NSDictionary *metrics = @{@"duration.nanos": [@(duration) stringValue]};
    [self reportMetrics:metrics measurement:measurement];
}

- (void)reportMetrics:(NSDictionary *)metrics measurement:(NSString *)measurement {
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSString *metricsEndpoint = [NSString stringWithFormat:@"%@/metrics", theBaseMazeAddress];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:metricsEndpoint]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableDictionary *body = [metrics mutableCopy];
    body[@"metric.measurement"] = measurement;
    body[@"device.manufacturer"] = [Bugsnag session].device.manufacturer ?: @"Apple";
    NSString *deviceModel = [Bugsnag session].device.model;
    NSString *systemVersion = [Bugsnag session].device.osVersion;
    if (deviceModel) {
        body[@"device.model"] = deviceModel;
    }
    if (systemVersion) {
        body[@"os.version"] = systemVersion;
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body
                                                       options:0
                                                         error:&error];
    if (!jsonData) {
        return;
    }
    [request setHTTPBody: jsonData];
    
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {}] resume];
}

- (void)requestDidComplete:(NSURLRequest *)request {
    dispatch_block_t block = _onEventDelivery;
    if (block && [request.URL.absoluteString isEqual:self.config.endpoints.notify]) {
        _onEventDelivery = nil;
        block();
    }
    block = _onSessionDelivery;
    if (block && [request.URL.absoluteString isEqual:self.config.endpoints.sessions]) {
        _onSessionDelivery = nil;
        block();
    }
}

// Pointer to the original implementation of -[NSURLSession uploadTaskWithRequest:fromData:completionHandler:]
static NSURLSessionUploadTask * (* NSURLSession_uploadTaskWithRequest_fromData_completionHandler)
 (NSURLSession *session, SEL _cmd, NSURLRequest *request, NSData *fromData, void (^ completionHandler)(NSData *, NSURLResponse *, NSError *));

// Custom implmentation of -[NSURLSession uploadTaskWithRequest:fromData:completionHandler:] to allow tracking when requests finish
static NSURLSessionUploadTask * uploadTaskWithRequest_fromData_completionHandler
 (NSURLSession *session, SEL _cmd, NSURLRequest *request, NSData *fromData, void (^ completionHandler)(NSData *, NSURLResponse *, NSError *)) {
     return NSURLSession_uploadTaskWithRequest_fromData_completionHandler(session, _cmd, request, fromData,
                                                                          ^(NSData *responseData, NSURLResponse *response, NSError *error) {
         completionHandler(responseData, response, error);
         [theScenario requestDidComplete:request];
     });
 }

+ (void)initialize {
    if (self == [Scenario self]) {
#if !TARGET_OS_WATCH
#if TARGET_OS_IPHONE
        NSString *logPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0]
                             stringByAppendingPathComponent:@"kscrash.log"];
#else
        NSString *logPath = @"/tmp/kscrash.log";
#endif
        [logPath getFileSystemRepresentation:ksLogPath maxLength:sizeof(ksLogPath)];
        bsg_kslog_setLogFilename(ksLogPath, false);
#endif
        Method method = class_getInstanceMethod([NSURLSession class], @selector(uploadTaskWithRequest:fromData:completionHandler:));
        NSURLSession_uploadTaskWithRequest_fromData_completionHandler =
        (void *)method_setImplementation(method, (void *)uploadTaskWithRequest_fromData_completionHandler);
    }
}

+ (void)clearPersistentData {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    NSString *cachesDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSArray<NSString *> *entries = @[
        @"bsg_kvstore",
        @"bsgkv",
        @"bugsnag",
        @"bugsnag_breadcrumbs.json",
        @"bugsnag_handled_crash.txt",
        @"KSCrash",
        @"KSCrashReports"];
    for (NSString *entry in entries) {
        NSString *path = [cachesDir stringByAppendingPathComponent:entry];
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:path error:&error]) {
            if (![error.domain isEqualToString:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
                NSLog(@"%@", error);
            }
        }
    }
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *rootDir = [appSupportDir stringByAppendingPathComponent:@"com.bugsnag.Bugsnag"];
    NSError *error = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:rootDir error:&error]) {
        if (![error.domain isEqualToString:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
            NSLog(@"%@", error);
        }
    }
#if !TARGET_OS_WATCH
    bsg_kslog_setLogFilename(ksLogPath, true);
#endif
}

+ (void)executeMazeRunnerCommand:(void (^)(NSString *action, NSString *scenarioName, NSString *scenarioMode))preHandler {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSString *commandEndpoint = [NSString stringWithFormat:@"%@/command", theBaseMazeAddress];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:commandEndpoint]];
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (![response isKindOfClass:[NSHTTPURLResponse class]] || [(NSHTTPURLResponse *)response statusCode] != 200) {
            NSLog(@"%s request failed with %@", __PRETTY_FUNCTION__, response ?: error);
            return;
        }
        NSLog(@"%s response body:  %@", __PRETTY_FUNCTION__, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSDictionary *command = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        
        NSString *action = [command objectForKey:@"action"];
        NSParameterAssert([action isKindOfClass:[NSString class]]);
        
        NSString *scenarioName = [command objectForKey:@"scenario_name"];
        NSParameterAssert([scenarioName isKindOfClass:[NSString class]]);
        
        NSString *eventMode = [command objectForKey:@"scenario_mode"];
        if ([eventMode isKindOfClass:[NSNull class]]) {
            eventMode = nil;
        }

        if ([[command objectForKey:@"reset_data"] isEqual:@YES]) {
            [self clearPersistentData];
        }

        if (preHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                preHandler(action, scenarioName, eventMode);
            });
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([action isEqualToString:@"run_scenario"]) {
                [self runScenario:scenarioName eventMode:eventMode];
            } else if ([action isEqualToString:@"start_bugsnag"]) {
                [self startBugsnagForScenario:scenarioName eventMode:eventMode];
            }
        });
    }] resume];
}

+ (void)runScenario:(NSString *)scenarioName eventMode:(NSString *)eventMode {
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, scenarioName, eventMode);
    
    [self startBugsnagForScenario:scenarioName eventMode:eventMode];
    
    [theScenario run];
}

+ (void)startBugsnagForScenario:(NSString *)scenarioName eventMode:(NSString *)eventMode {
    NSLog(@"%s %@ %@", __PRETTY_FUNCTION__, scenarioName, eventMode);
    
    theScenario = [Scenario createScenarioNamed:scenarioName withConfig:nil];
    theScenario.eventMode = eventMode;
    
    NSLog(@"Starting scenario \"%@\"", NSStringFromClass([self class]));
    [theScenario startBugsnag];
}

@end
