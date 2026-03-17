@import XCTest;

#import <objc/runtime.h>

#import "BSGTestCase.h"
#import <Bugsnag/BugsnagConfiguration.h>

@interface BSGLoadConfigTests : BSGTestCase
@end

static NSDictionary *_Nullable bsg_testInfoDictionary;

#if TARGET_OS_WATCH

@interface BSGTestMainBundleProxy : NSProxy
@property(nonatomic, strong) NSBundle *bundle;
@end

@implementation BSGTestMainBundleProxy

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [self.bundle methodSignatureForSelector:sel] ?: [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if (self.bundle) {
        [invocation setTarget:self.bundle];
        [invocation invoke];
    }
}

- (NSDictionary<NSString *, id> *)infoDictionary {
    return bsg_testInfoDictionary;
}

@end

static IMP _Nullable bsg_originalMainBundleIMP;

#endif

@implementation NSBundle (BSGLoadConfigTests)

- (NSDictionary * _Nullable)bsg_test_infoDictionary {
    return bsg_testInfoDictionary;
}

@end

@implementation BSGLoadConfigTests

- (void)setUp {
    [super setUp];

#if TARGET_OS_WATCH
    // Swizzle +[NSBundle mainBundle] to return a proxy whose -infoDictionary is controllable.
    // (On watchOS, mainBundle is already a proxy, so swizzling -infoDictionary doesn't affect it.)
    if (bsg_originalMainBundleIMP == nil) {
        Method mainBundleMethod = class_getClassMethod([NSBundle class], @selector(mainBundle));
        bsg_originalMainBundleIMP = method_getImplementation(mainBundleMethod);

        method_setImplementation(mainBundleMethod, imp_implementationWithBlock(^NSBundle *{
            NSBundle *(*orig)(id, SEL) = (NSBundle *(*)(id, SEL))bsg_originalMainBundleIMP;
            NSBundle *realBundle = orig([NSBundle class], @selector(mainBundle));
            BSGTestMainBundleProxy *proxy = [BSGTestMainBundleProxy alloc];
            proxy.bundle = realBundle;
            return (NSBundle *)proxy;
        }));
    }

    // Default dictionary includes the watch extension keys so extension detection is satisfied.
    bsg_testInfoDictionary = @{
        @"NSExtension": @{
            @"NSExtensionAttributes": @{
                @"WKAppBundleIdentifier": @"com.bugsnag.swift-watchos.watchkitapp",
            },
            @"NSExtensionPointIdentifier": @"com.apple.watchkit",
        },
    };
#else
    // Swizzle -[NSBundle infoDictionary] so tests can inject plist values.
    Method original = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
    Method replacement = class_getInstanceMethod([NSBundle class], @selector(bsg_test_infoDictionary));
    method_exchangeImplementations(original, replacement);

    bsg_testInfoDictionary = @{};
#endif
}

- (void)tearDown {
#if !TARGET_OS_WATCH
    // Restore swizzle
    Method original = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
    Method replacement = class_getInstanceMethod([NSBundle class], @selector(bsg_test_infoDictionary));
    method_exchangeImplementations(original, replacement);
#endif

    bsg_testInfoDictionary = nil;

    [super tearDown];
}

- (void)testLoadConfig_UsesCapitalBugsnagWhenItIsNSDictionary {
    bsg_testInfoDictionary = @{
        @"Bugsnag": @{
            @"apiKey": @"0192837465afbecd0192837465afbecd",
            @"releaseStage": @"capital"
        },
        @"bugsnag": @{
            @"apiKey": @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            @"releaseStage": @"lowercase"
        }
    };

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.apiKey, @"0192837465afbecd0192837465afbecd");
    XCTAssertEqualObjects(config.releaseStage, @"capital");
}

- (void)testLoadConfig_FallsBackToLowercaseWhenCapitalBugsnagIsNotNSDictionary {
    bsg_testInfoDictionary = @{
        @"Bugsnag": @"not a dictionary",
        @"bugsnag": @{
            @"apiKey": @"0192837465afbecd0192837465afbecd",
            @"releaseStage": @"fallback"
        }
    };

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.apiKey, @"0192837465afbecd0192837465afbecd");
    XCTAssertEqualObjects(config.releaseStage, @"fallback");
}

- (void)testLoadConfig_UsesLowercaseWhenOnlyLowercaseExistsAndIsNSDictionary {
    bsg_testInfoDictionary = @{
        @"bugsnag": @{
            @"apiKey": @"0192837465afbecd0192837465afbecd",
            @"releaseStage": @"lowercaseOnly"
        }
    };

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.apiKey, @"0192837465afbecd0192837465afbecd");
    XCTAssertEqualObjects(config.releaseStage, @"lowercaseOnly");
}

- (void)testLoadConfig_PassesNilOptionsWhenNeitherKeyIsNSDictionary {
    bsg_testInfoDictionary = @{
        @"Bugsnag": @123,
        @"bugsnag": @"also not a dictionary"
    };

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

- (void)testLoadConfig_PassesNilOptionsWhenNoKeysPresent {
    bsg_testInfoDictionary = @{
        @"CFBundleName": @"UnitTestHost"
    };

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

- (void)testLoadConfig_HandlesNilInfoDictionary {
    bsg_testInfoDictionary = nil;

    BugsnagConfiguration *config = [BugsnagConfiguration loadConfig];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

@end
