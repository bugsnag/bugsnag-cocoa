@import XCTest;

#import <objc/runtime.h>

#import <Bugsnag/BugsnagConfiguration.h>

@interface BSGLoadConfigTests : XCTestCase
@end

static NSDictionary *_Nullable bsg_testInfoDictionary;

@implementation NSBundle (BSGLoadConfigTests)

- (NSDictionary * _Nullable)bsg_test_infoDictionary {
    return bsg_testInfoDictionary;
}

@end

@implementation BSGLoadConfigTests

- (void)setUp {
    [super setUp];

    // Swizzle -[NSBundle infoDictionary] so tests can inject plist values.
    Method original = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
    Method replacement = class_getInstanceMethod([NSBundle class], @selector(bsg_test_infoDictionary));
    method_exchangeImplementations(original, replacement);

    bsg_testInfoDictionary = @{};
}

- (void)tearDown {
    // Restore swizzle
    Method original = class_getInstanceMethod([NSBundle class], @selector(infoDictionary));
    Method replacement = class_getInstanceMethod([NSBundle class], @selector(bsg_test_infoDictionary));
    method_exchangeImplementations(original, replacement);

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
