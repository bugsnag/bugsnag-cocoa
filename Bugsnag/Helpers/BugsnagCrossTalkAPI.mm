//
//  BugsnagCrossTalkAPI.mm
//  Bugsnag
//
//  Created by Robert Bartoszewski on 27/03/2026.
//  Copyright © 2026 Bugsnag Inc. All rights reserved.
//

#import "BugsnagCrossTalkAPI.h"
#import "BugsnagClient.h"
#import "BugsnagClient+Private.h"
#import "BugsnagEvent.h"
#import "BugsnagStackframe.h"
#import "BugsnagLogger.h"
#import <objc/runtime.h>


@interface BugsnagCrossTalkAPI ()

@property(nonatomic, weak) BugsnagClient *client;

@end


@implementation BugsnagCrossTalkAPI

+ (void)initializeWithClient:(BugsnagClient *)client {
    BugsnagCrossTalkAPI.sharedInstance.client = client;
}

#pragma mark - Exposed API

/**
 * Create a plain event without automatic enrichment.
 * API Version: V1
 *
 * This is designed for external diagnostic systems (like MetricKit) that provide
 * their own timestamp and don't need breadcrumbs, feature flags, etc.
 */
- (void)notifyPlainEventV1:(NSString *)errorClass
              errorMessage:(NSString *)errorMessage
                stacktrace:(NSArray<BugsnagStackframe *> *)stacktrace
                 timestamp:(NSDate * _Nullable)timestamp
                     block:(BOOL (^ _Nullable)(BugsnagEvent *event))block {
    BugsnagClient *client = self.client;
    if (client == nil) {
        bsg_log_warn(@"CrossTalk: Cannot notify plain event - Bugsnag not initialized");
        return;
    }
    
    [client notifyPlainEventWithErrorClass:errorClass
                              errorMessage:errorMessage
                                stacktrace:stacktrace
                                 timestamp:timestamp
                                     block:block];
}

#pragma mark - Internal Functionality

static NSString *BSGUserInfoKeyIsSafeToCall = @"isSafeToCall";
static NSString *BSGUserInfoKeyWillNOOP = @"willNOOP";

static bool classImplementsSelector(Class cls, SEL selector) {
    bool selectorExists = false;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        if (method_getName(methods[i]) == selector) {
            selectorExists = true;
            break;
        }
    }
    free(methods);
    return selectorExists;
}

/**
 * Map a named API to a method with the specified selector.
 *
 * If an error occurs, the user info dictionary will contain the following NSNumber (boolean) fields:
 *  - "isSafeToCall": If @(YES), this method is safe to call (it has an implementation). Otherwise, calling it WILL throw a selector-not-found exception.
 *  - "willNOOP": If @(YES), calling the mapped method will no-op.
 *
 * Common scenarios:
 *  - The host library isn't linked in: isSafeToCall = YES, willNOOP = YES
 *  - apiName doesn't exist: isSafeToCall = YES, willNOOP = YES
 *  - toSelector already exists: isSafeToCall = YES, willNOOP = NO
 *  - Tried to map the same thing twice: isSafeToCall = YES, willNOOP = NO
 *  - Selector signature clash: isSafeToCall = NO, willNOOP = NO
 */
+ (NSError *)mapAPINamed:(NSString * _Nonnull)apiName toSelector:(SEL)toSelector {
    NSError *err = nil;
    // By default, we map to a "do nothing" implementation in case we don't find a real one.
    SEL fromSelector = @selector(internal_doNothing);

    // apiName should map to an existing method in this API
    SEL apiSelector = NSSelectorFromString(apiName);
    if (classImplementsSelector(self.class, apiSelector)) {
        fromSelector = apiSelector;
    } else {
        err = [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:@"No such API: %@", apiName],
            BSGUserInfoKeyIsSafeToCall:@YES,
            BSGUserInfoKeyWillNOOP:@YES
        }];
    }

    Method method = class_getInstanceMethod(self.class, fromSelector);
    if (method == nil) {
        return [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                       @"class_getInstanceMethod (while mapping api %@): Failed to find instance method %@ in class %@",
                                       apiName,
                                       NSStringFromSelector(fromSelector),
                                       self.class],
            BSGUserInfoKeyIsSafeToCall:@NO,
            BSGUserInfoKeyWillNOOP:@NO
        }];
    }

    IMP imp = method_getImplementation(method);
    if (imp == nil) {
        return [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                       @"method_getImplementation (while mapping api %@): Failed to find implementation of instance method %@ in class %@",
                                       apiName,
                                       NSStringFromSelector(fromSelector),
                                       self.class],
            BSGUserInfoKeyIsSafeToCall:@NO,
            BSGUserInfoKeyWillNOOP:@NO
        }];
    }

    const char* encoding = method_getTypeEncoding(method);
    if (encoding == nil) {
        return [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                       @"method_getTypeEncoding (while mapping api %@): Failed to find signature of instance method %@ in class %@",
                                       apiName,
                                       NSStringFromSelector(fromSelector),
                                       self.class],
            BSGUserInfoKeyIsSafeToCall:@NO,
            BSGUserInfoKeyWillNOOP:@NO
        }];
    }

    // Don't add a method that already exists
    if (classImplementsSelector(self.class, toSelector)) {
        return [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                       @"class_addMethod (while mapping api %@): Instance method %@ already exists in class %@",
                                       apiName,
                                       NSStringFromSelector(fromSelector),
                                       self.class],
            BSGUserInfoKeyIsSafeToCall:@YES,
            BSGUserInfoKeyWillNOOP:@NO
        }];
    }

    if (!class_addMethod(self.class, toSelector, imp, encoding)) {
        return [NSError errorWithDomain:@"com.bugsnag.Bugsnag"
                                  code:0
                              userInfo:@{
            NSLocalizedDescriptionKey:[NSString stringWithFormat:
                                       @"class_addMethod (while mapping api %@): Failed to add instance method %@ to class %@",
                                       apiName,
                                       NSStringFromSelector(fromSelector),
                                       self.class],
            BSGUserInfoKeyIsSafeToCall:@NO,
            BSGUserInfoKeyWillNOOP:@NO
        }];
    }

    return err;
}

- (void * _Nullable)internal_doNothing {
    return NULL;
}

+ (instancetype)sharedInstance {
    static BugsnagCrossTalkAPI *sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

@end


#pragma mark - BugsnagCrossTalkProxiedObject

@interface BugsnagCrossTalkProxiedObject ()

@property(nonatomic,strong) id delegate;

@end

@implementation BugsnagCrossTalkProxiedObject

+ (instancetype _Nullable) proxied:(id _Nullable)delegate {
    if (delegate == nil) {
        return nil;
    }

    BugsnagCrossTalkProxiedObject *proxy = [BugsnagCrossTalkProxiedObject alloc];
    proxy.delegate = delegate;
    return proxy;
}

// Allow faster access to ivars in these special cases
#pragma clang diagnostic ignored "-Wdirect-ivar-access"

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    if ([_delegate respondsToSelector:anInvocation.selector]) {
        [anInvocation setTarget:_delegate];
        [anInvocation invoke];
    }
}

-(NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [_delegate methodSignatureForSelector:aSelector];
    if (sig) {
        return sig;
    }

    bsg_log_warn(@"CrossTalk: Tried to invoke unimplemented selector [%@] on proxied object %@",
                  NSStringFromSelector(aSelector), [_delegate debugDescription]);

    // Return a no-arg signature that's guaranteed to exist
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

#pragma mark NSObject protocol (BugsnagCrossTalkProxiedObject)

- (Class)class {
    return [_delegate class];
}

- (Class)superclass {
    return [_delegate superclass];
}

- (BOOL)isKindOfClass:(Class)aClass {
    return [_delegate isKindOfClass:aClass];
}

- (BOOL)isMemberOfClass:(Class)aClass {
    return [_delegate isMemberOfClass:aClass];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    // Be truthful about this
    return [_delegate respondsToSelector:aSelector];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    // Be truthful about this
    return [_delegate conformsToProtocol:aProtocol];
}

- (BOOL)isEqual:(id)object {
    return [_delegate isEqual:object];
}

- (NSUInteger)hash {
    return [_delegate hash];
}

- (BOOL)isProxy {
    return YES;
}

- (NSString *)description {
    if (_delegate) {
        return [_delegate description];
    }
    return super.description;
}

- (NSString *)debugDescription {
    if (_delegate) {
        return [_delegate debugDescription];
    }
    return super.debugDescription;
}

@end
