//
//  BugsnagSharedSessionProxy.mm
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 06/03/2026.
//

#import <Foundation/Foundation.h>
#import "BugsnagSharedSessionProxy.h"
#import <objc/runtime.h>

#define FINISH_TASK_AND_INVALIDATE_SELECTOR @selector(finishTasksAndInvalidate)
#define INVALIDATE_AND_CANCEL_SELECTOR @selector(invalidateAndCancel)

@interface BugsnagSharedSessionProxy ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation BugsnagSharedSessionProxy

+ (BOOL)respondsToSelector:(SEL)aSelector {
    return [NSURLSession respondsToSelector:aSelector];
}

+ (Class)class {
    return [NSURLSession class];
}

+ (BOOL)selectorShouldBeForwarded:(SEL)aSelector {
    return !(sel_isEqual(aSelector, FINISH_TASK_AND_INVALIDATE_SELECTOR) ||
             sel_isEqual(aSelector, INVALIDATE_AND_CANCEL_SELECTOR));
}

- (id)initWithSession:(NSURLSession *)session {
    _session = session;
    return self;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([BugsnagSharedSessionProxy selectorShouldBeForwarded:aSelector]) {
        return self.session;
    } else {
        return self;
    }
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if (![BugsnagSharedSessionProxy selectorShouldBeForwarded:invocation.selector]) {
        return;
    }
    [self.session forwardInvocation:invocation];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.session methodSignatureForSelector:sel];
}

@end
