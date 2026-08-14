@import XCTest;

#import <Bugsnag/BugsnagConfiguration.h>
#import "BSGTestCase.h"

#import "BugsnagConfiguration+Private.h"

@interface BSGLoadConfigTests : BSGTestCase
@end

@interface BSGTestBundle : NSObject
@property(nonatomic, nullable) NSDictionary *bsg_infoDictionary;
@end

@implementation BSGTestBundle
- (NSDictionary * _Nullable)infoDictionary {
    return self.bsg_infoDictionary;
}
@end

@implementation BSGLoadConfigTests

- (void)testLoadConfig_PrefersCapitalBugsnagWhenPresentAndNSDictionary {
    BSGTestBundle *bundle = [BSGTestBundle new];
    bundle.bsg_infoDictionary = @{
        @"Bugsnag": @{
            @"apiKey": @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            @"releaseStage": @"capital"
        },
        @"bugsnag": @{
            @"apiKey": @"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            @"releaseStage": @"lowercase"
        }
    };

    BugsnagConfiguration *config = [BugsnagConfiguration bsg_loadConfigWithBundle:(NSBundle *)bundle];

    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.apiKey, @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    XCTAssertEqualObjects(config.releaseStage, @"capital");
}

- (void)testLoadConfig_FallsBackToLowercaseWhenCapitalBugsnagIsNotNSDictionary {
    BSGTestBundle *bundle = [BSGTestBundle new];
    bundle.bsg_infoDictionary = @{
        @"Bugsnag": @"not a dictionary",
        @"bugsnag": @{
            @"apiKey": @"0192837465afbecd0192837465afbecd",
            @"releaseStage": @"fallback"
        }
    };

    BugsnagConfiguration *config = [BugsnagConfiguration bsg_loadConfigWithBundle:(NSBundle *)bundle];

    XCTAssertNotNil(config);
    XCTAssertEqualObjects(config.apiKey, @"0192837465afbecd0192837465afbecd");
    XCTAssertEqualObjects(config.releaseStage, @"fallback");
}

- (void)testLoadConfig_PassesNilOptionsWhenNeitherKeyIsNSDictionary {
    BSGTestBundle *bundle = [BSGTestBundle new];
    bundle.bsg_infoDictionary = @{
        @"Bugsnag": @123,
        @"bugsnag": @"also not a dictionary"
    };

    BugsnagConfiguration *config = [BugsnagConfiguration bsg_loadConfigWithBundle:(NSBundle *)bundle];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

- (void)testLoadConfig_PassesNilOptionsWhenNoKeysPresent {
    BSGTestBundle *bundle = [BSGTestBundle new];
    bundle.bsg_infoDictionary = @{
        @"CFBundleName": @"UnitTestHost"
    };

    BugsnagConfiguration *config = [BugsnagConfiguration bsg_loadConfigWithBundle:(NSBundle *)bundle];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

- (void)testLoadConfig_HandlesNilInfoDictionary {
    BSGTestBundle *bundle = [BSGTestBundle new];
    bundle.bsg_infoDictionary = nil;

    BugsnagConfiguration *config = [BugsnagConfiguration bsg_loadConfigWithBundle:(NSBundle *)bundle];

    XCTAssertNotNil(config);
    XCTAssertNil(config.apiKey);
}

@end
