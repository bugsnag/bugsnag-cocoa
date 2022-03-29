//
//  BSGURLSessionTracingProxy.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import "BSGURLSessionTracingProxy.h"
#import <objc/runtime.h>


@interface BSGURLSessionTracingProxy ()

@property (nonatomic, strong, nonnull) id delegate;
@property (nonatomic, strong, nonnull) BSGURLSessionTracingDelegate *tracingDelegate;

@end


@implementation BSGURLSessionTracingProxy

#define METRICS_SELECTOR @selector(URLSession:task:didFinishCollectingMetrics:)

- (instancetype)initWithDelegate:(nonnull id<NSURLSessionDelegate>)delegate
                 tracingDelegate:(nonnull BSGURLSessionTracingDelegate *) tracingDelegate {
    _delegate = delegate;
    _tracingDelegate = tracingDelegate;

    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (self.tracingDelegate.canTrace && sel_isEqual(aSelector, METRICS_SELECTOR)) {
        return YES;
    }
    return [self.delegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(__unused SEL)aSelector {
    return self.delegate;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0)) {
    [self.tracingDelegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    
    if ([self.delegate respondsToSelector:METRICS_SELECTOR]) {
        [self.delegate URLSession:session task:task didFinishCollectingMetrics:metrics];
    }
}

@end
