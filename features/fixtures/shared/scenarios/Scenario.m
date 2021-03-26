//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//
#import <objc/runtime.h>

#import "Scenario.h"

void markErrorHandledCallback(const BSG_KSCrashReportWriter *writer) {
    writer->addBooleanElement(writer, "unhandled", false);
}

// MARK: -

static Scenario *theScenario;

@implementation Scenario {
    dispatch_block_t _onEventDelivery;
}

+ (Scenario *)createScenarioNamed:(NSString *)className
                       withConfig:(BugsnagConfiguration *)config {
    Class clz = NSClassFromString(className);

#if TARGET_OS_IPHONE
    NSString *swiftPrefix = @"iOSTestApp.";
#elif TARGET_OS_OSX
    NSString *swiftPrefix = @"macOSTestApp.";
#endif

    if (!clz) { // Case-insensitive class lookup because AppiumForMac is a bit unreliable at entering uppercase characters.
        unsigned int classCount = 0;
        Class *classes = objc_copyClassList(&classCount);
        for (unsigned int i = 0; i < classCount; i++) {
            NSString *name = NSStringFromClass(classes[i]);
            if ([name hasPrefix:swiftPrefix]) {
                name = [name substringFromIndex:swiftPrefix.length];
            }
            if ([name caseInsensitiveCompare:className] == NSOrderedSame) {
                clz = classes[i];
                break;
            }
        }
        free(classes);
    }

    if (!clz) {
        [NSException raise:NSInvalidArgumentException format:@"Failed to find scenario class named %@", className];
    }

    id obj = [clz alloc];

    NSAssert([obj isKindOfClass:[Scenario class]], @"Class '%@' is not a subclass of Scenario", className);

    theScenario = obj;

    return [(Scenario *)obj initWithConfig:config];
}

- (instancetype)initWithConfig:(BugsnagConfiguration *)config {
    if (self = [super init]) {
        self.config = config;
    }
    return self;
}

- (void)waitForNetworkConnectivity {
    NSDictionary *proxySettings = (__bridge_transfer NSDictionary *)CFNetworkCopySystemProxySettings();
    NSLog(@"*** Proxy settings = %@", proxySettings);
    
    // This check uses HTTP rather than sockets because connectivity is commonly provided via an HTTP proxy.
    
    NSURL *url = [NSURL URLWithString:self.config.endpoints.notify];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3];
    NSLog(@"*** Checking for connectivity to %@", url);
    while (1) {
        NSURLResponse *response = nil;
        NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
#pragma clang diagnostic pop
        if ([response isKindOfClass:[NSHTTPURLResponse class]] && ((NSHTTPURLResponse *)response).statusCode / 100 == 2) {
            NSLog(@"*** Received response from notify endpoint.");
            break;
        }
        NSLog(@"*** No response from notify endpoint, retrying in 1 second...");
        [NSThread sleepForTimeInterval:1];
    }
}

- (void)run {
    // Must be implemented by all subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)startBugsnag {
    // TODO: PLAT-5827
    // [self waitForNetworkConnectivity]; // Disabled for now because MR v4 does not listen on /
    [Bugsnag startWithConfiguration:self.config];
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

- (void)requestDidComplete:(NSURLRequest *)request {
    dispatch_block_t block = _onEventDelivery;
    if (block && [request.URL.absoluteString isEqual:self.config.endpoints.notify]) {
        _onEventDelivery = nil;
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
        Method method = class_getInstanceMethod([NSURLSession class], @selector(uploadTaskWithRequest:fromData:completionHandler:));
        NSURLSession_uploadTaskWithRequest_fromData_completionHandler =
        (void *)method_setImplementation(method, (void *)uploadTaskWithRequest_fromData_completionHandler);
    }
}

@end
