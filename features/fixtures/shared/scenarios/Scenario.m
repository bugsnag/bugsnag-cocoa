//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//
#import "Scenario.h"
#import "Logging.h"

#import <objc/runtime.h>

#if TARGET_OS_IOS
#define SWIFT_MODULE "iOSTestApp"
#import <UIKit/UIKit.h>
#import "iOSTestApp-Swift.h"
#elif TARGET_OS_OSX
#elif TARGET_OS_WATCH
#import "watchos_maze_host.h"
#define SWIFT_MODULE "watchOSTestApp_WatchKit_Extension"
#else
#error Unsupported TARGET_OS
#endif

extern bool bsg_kslog_setLogFilename(const char *filename, bool overwrite);

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer) {
    writer->addBooleanElement(writer, "unhandled", false);
}

// MARK: -

#if !TARGET_OS_WATCH
static char ksLogPath[PATH_MAX];
#endif

static __weak Scenario *currentScenario;

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
        logDebug(@"Received notification %@", notification.name);
    }];
}

- (instancetype)initWithFixtureConfig:(FixtureConfig *)fixtureConfig args:(NSArray<NSString *> *)args launchCount:(NSInteger)launchCount {
    if (self = [super init]) {
        _fixtureConfig = fixtureConfig;
        _args = args;
        currentScenario = self;
        _launchCount = launchCount;
    }
    return self;
}

- (void)configure {
    self.config = [[BugsnagConfiguration alloc] initWithApiKey:self.fixtureConfig.apiKey];
    self.config.endpoints.notify = self.fixtureConfig.notifyURL.absoluteString;
    self.config.endpoints.sessions = self.fixtureConfig.sessionsURL.absoluteString;
#if !TARGET_OS_WATCH
    self.config.enabledErrorTypes.ooms = NO;
#endif
}

- (void)run {
    // Must be implemented by all subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)startBugsnag {
    [Bugsnag startWithConfiguration:self.config];
}

- (void)didEnterBackgroundNotification {
}

- (void)enterBackgroundForSeconds:(NSInteger)seconds {
#if __has_include(<UIKit/UIKit.h>)
    if (@available(iOS 10.0, *)) {
        NSString *documentName = @"background_forever.html";
        if (seconds >= 0) {
            documentName = [NSString stringWithFormat:@"background_for_%ld_sec.html", (long)seconds];
        }
        NSURL *url = [self.fixtureConfig.docsURL URLByAppendingPathComponent:documentName];

        logInfo(@"Backgrounding the app using %@", documentName);
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
            NSLog(@"Opened %@ %@", url, success ? @"successfully" : @"unsuccessfully");
        }];
    }
#else
    [NSException raise:@"Mazerunner fixture error"
                format:@"This e2e test requires UIApplication, which is not available on this platform."];
#endif
}

-(void)waitForEventDelivery:(dispatch_block_t)deliveryBlock andThen:(dispatch_block_t)thenBlock {
    _onEventDelivery = ^{
        dispatch_async(dispatch_get_main_queue(), thenBlock);
    };
    deliveryBlock();
}

-(void)waitForSessionDelivery:(dispatch_block_t)deliveryBlock andThen:(dispatch_block_t)thenBlock {
    _onSessionDelivery = ^{
        dispatch_async(dispatch_get_main_queue(), thenBlock);
    };
    deliveryBlock();
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
         [currentScenario requestDidComplete:request];
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
    logInfo(@"%s", __PRETTY_FUNCTION__);
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
                logError(@"Error removing path %@: %@", path, error);
            }
        }
    }
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *rootDir = [appSupportDir stringByAppendingPathComponent:@"com.bugsnag.Bugsnag"];
    NSError *error = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:rootDir error:&error]) {
        if (![error.domain isEqualToString:NSCocoaErrorDomain] && error.code != NSFileNoSuchFileError) {
            logError(@"Error removing path %@: %@", rootDir, error);
        }
    }
#if !TARGET_OS_WATCH
    bsg_kslog_setLogFilename(ksLogPath, true);
#endif
}

@end
