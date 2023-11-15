//
//  BSGTestCase.m
//  Bugsnag
//
//  Created by Karl Stenerud on 10.11.23.
//  Copyright © 2023 Bugsnag Inc. All rights reserved.
//

#import "BSGTestCase.h"
#import "Swizzle.h"
#import <stdatomic.h>

using namespace bugsnag;

@interface BSGWatchKitBundle: NSProxy

@property(nonatomic,readwrite) NSBundle *bundle;
@property(nonatomic,readwrite) NSDictionary *dict;

- (instancetype) initWithBundle:(NSBundle *)bundle;

@end

@implementation BSGWatchKitBundle

- (instancetype) initWithBundle:(NSBundle *)bundle {
    // Force the main bundle's dictionary to have an NSExtension section on WatchOS.
    // This is necessary because the unit tests run in an extension environment but
    // don't set this field that is normally present in a real environment, which
    // confuses our extension detection code in
    // Bugsnag/KSCrash/Source/KSCrash/Recording/BSG_KSSystemInfo.m
    NSMutableDictionary *dict = [NSBundle.mainBundle.infoDictionary mutableCopy];
    if (dict[@"NSExtension"] == nil) {
        dict[@"NSExtension"] = @{
            @"NSExtensionAttributes": @{
                @"WKAppBundleIdentifier": @"com.bugsnag.swift-watchos.watchkitapp",
            },
            @"NSExtensionPointIdentifier": @"com.apple.watchkit",
        };
    }
    _dict = dict;
    _bundle = bundle;

    return self;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if (self.bundle) {
        [invocation setTarget:self.bundle];
        [invocation invoke];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    if ([self.bundle methodSignatureForSelector:sel]) {
        return [self.bundle methodSignatureForSelector:sel];
    } else {
        return [super methodSignatureForSelector:sel];
    }
}

- (NSDictionary<NSString *, id> *)infoDictionary {
    return self.dict;
}

@end


@implementation BSGTestCase

- (void)setUp {
    if ([super respondsToSelector:@selector(setUp)]) {
        [super setUp];
    }

#if TARGET_OS_WATCH
    static _Atomic(bool) hasSwizzled = false;
    bool expectedValue = false;
    if (atomic_compare_exchange_strong(&hasSwizzled, &expectedValue, true)) {
        BSGWatchKitBundle *bundleProxy = [[BSGWatchKitBundle alloc] initWithBundle:NSBundle.mainBundle];
        ObjCSwizzle::setClassMethodImplementation(NSBundle.class, @selector(mainBundle), ^NSBundle *{
            return (NSBundle *)bundleProxy;
        });
    }

#endif
}

@end
