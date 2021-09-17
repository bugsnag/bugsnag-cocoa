//
//  BSGURLSessionTracingProxy.m
//  
//
//  Created by Karl Stenerud on 07.09.21.
//

#import "BSGURLSessionTracingProxy.h"
#import <objc/runtime.h>


@interface BSGURLSessionTracingProxy ()

@property (nonatomic, strong, nonnull) id<NSURLSessionDelegate> delegate;
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

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    // Note: We allow a race condition on self.tracingDelegate.canTrace because the
    //       caller has already determined that we respond to selector, and it would
    //       break things to stop "supporting" it now. We'll catch this edge case in
    //       forwardInvocation, and again in the call to tracingDelegate.
    if (sel_isEqual(aSelector, METRICS_SELECTOR)) {
        return [(NSObject *)self.tracingDelegate methodSignatureForSelector:aSelector];
    }
    return [(NSObject *)self.delegate methodSignatureForSelector:aSelector];
}

-  (void)forwardInvocation:(NSInvocation *)invocation {
    if (sel_isEqual(invocation.selector, METRICS_SELECTOR)) {
        if (self.tracingDelegate.canTrace) {
            invocation.target = self.tracingDelegate;
            [invocation invoke];
        }

        if (![self.delegate respondsToSelector:METRICS_SELECTOR]) {
            return;
        }
    }

    invocation.target = self.delegate;
    [invocation invoke];
}

@end
