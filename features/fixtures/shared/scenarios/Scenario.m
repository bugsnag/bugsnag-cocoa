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

typedef void (^ URLSessionResponseObserver)(NSURLRequest *request, NSData *responseData, NSURLResponse *response, NSError *error);

@interface ObservableURLSession : NSObject

+ (instancetype)sessionWithObserver:(URLSessionResponseObserver)observer;

@property (copy, nonatomic) URLSessionResponseObserver observer;

@end


// MARK: -

@implementation Scenario

+ (Scenario *)createScenarioNamed:(NSString *)className
                       withConfig:(BugsnagConfiguration *)config {
    Class clz = NSClassFromString(className);

    if (clz == nil) { // swift class
#if TARGET_OS_IPHONE
        clz = NSClassFromString([NSString stringWithFormat:@"iOSTestApp.%@", className]);
#elif TARGET_OS_MAC
        clz = NSClassFromString([NSString stringWithFormat:@"macOSTestApp.%@", className]);
#endif
    }

    NSAssert(clz != nil, @"Failed to find class named '%@'", className);

    BOOL implementsRun = method_getImplementation(class_getInstanceMethod([Scenario class], @selector(run))) !=
    method_getImplementation(class_getInstanceMethod(clz, @selector(run)));

    NSAssert(implementsRun, @"Class '%@' does not implement the run method", className);

    id obj = [clz alloc];

    NSAssert([obj isKindOfClass:[Scenario class]], @"Class '%@' is not a subclass of Scenario", className);

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
}

- (void)startBugsnag {
    // TODO: PLAT-5827
    // [self waitForNetworkConnectivity]; // Disabled for now because MR v4 does not listen on /
    [Bugsnag startWithConfiguration:self.config];
}

- (void)didEnterBackgroundNotification {
}

- (NSURLSession *)URLSessionWithObserver:(URLSessionResponseObserver)observer {
    return (id)[ObservableURLSession sessionWithObserver:observer];
}

@end


// MARK: -

@implementation ObservableURLSession

// NSURLSession does not allow subclassing - calling [ObservableURLSession sessionWithConfiguration:] will return an
// instance of NSURLSession instead of ObservableURLSession, so we have to resort to acting as a proxy object.

+ (instancetype)sessionWithObserver:(URLSessionResponseObserver)observer {
    ObservableURLSession *session = [[ObservableURLSession alloc] init];
    session.observer = observer;
    return session;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData
                                completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    return [NSURLSession.sharedSession uploadTaskWithRequest:request fromData:bodyData completionHandler:
            ^(NSData *responseData, NSURLResponse *response, NSError *error) {
        completionHandler(responseData, response, error);
        if (self.observer) {
            self.observer(request, responseData, response, error);
        }
    }];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return NSURLSession.sharedSession;
}

@end
