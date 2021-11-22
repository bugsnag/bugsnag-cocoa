#import <XCTest/XCTest.h>
#import "BugsnagSystemState.h"
#import "BSG_KSSystemInfo.h"
#import "BugsnagConfiguration.h"
#import "Bugsnag.h"
#import "BugsnagClient+Private.h"
#import "BugsnagTestConstants.h"
#import "BugsnagKVStoreObjC.h"
#import "BSGFileLocations.h"

#import <objc/runtime.h>

@interface BSGOutOfMemoryTests : XCTestCase
@end

@implementation BSGOutOfMemoryTests

- (BugsnagClient *)newClient {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
//    config.autoDetectErrors = NO;
    config.releaseStage = @"MagicalTestingTime";

    return [[BugsnagClient alloc] initWithConfiguration:config];
}

/**
 * Test that the generated OOM report values exist and are correct (where that can be tested)
 */
- (void)testOOMFieldsSetCorrectly {
    BugsnagClient *client = [self newClient];
    BugsnagSystemState *systemState = [client systemState];

    client.codeBundleId = @"codeBundleIdHere";
    // The update happens on a bg thread, so let it run.
    [NSThread sleepForTimeInterval:0.01f];
    NSDictionary *state = systemState.currentLaunchState;
    XCTAssertNotNil([state objectForKey:@"app"]);
    XCTAssertNotNil([state objectForKey:@"device"]);
    
    NSDictionary *app = [state objectForKey:@"app"];
    XCTAssertNotNil([app objectForKey:@"bundleVersion"]);
    XCTAssertNotNil([app objectForKey:@"id"]);
    XCTAssertNotNil([app objectForKey:@"inForeground"]);
    XCTAssertNotNil([app objectForKey:@"version"]);
    XCTAssertNotNil([app objectForKey:@"name"]);
    XCTAssertEqualObjects([app valueForKey:@"codeBundleId"], @"codeBundleIdHere");
    XCTAssertEqualObjects([app valueForKey:@"releaseStage"], @"MagicalTestingTime");
    
    NSDictionary *device = [state objectForKey:@"device"];
    XCTAssertNotNil([device objectForKey:@"osName"]);
    XCTAssertNotNil([device objectForKey:@"osBuild"]);
    XCTAssertNotNil([device objectForKey:@"osVersion"]);
    XCTAssertNotNil([device objectForKey:@"id"]);
    XCTAssertNotNil([device objectForKey:@"model"]);
    XCTAssertNotNil([device objectForKey:@"simulator"]);
    XCTAssertNotNil([device objectForKey:@"wordSize"]);
    XCTAssertEqualObjects([device valueForKey:@"locale"], [[NSLocale currentLocale] localeIdentifier]);
}

-(void)testBadJSONData {
    NSString *stateFilePath = [BSGFileLocations current].systemState;
    NSError* error;
    [@"{1=\"a\"" writeToFile:stateFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);

    // Should not crash
    [self newClient];
}

- (void)testLastLaunchTerminatedUnexpectedly {
    Method isRunningInAppExtension = class_getClassMethod([BSG_KSSystemInfo class], @selector(isRunningInAppExtension));
    IMP originalImp = method_setImplementation(isRunningInAppExtension, imp_implementationWithBlock(^{
        // Xcode's unit test runner has no CFBundlePackageType, which causes +isRunningInAppExtension to return YES and disables
        // unexpected termination / OOM detection.
        return NO;
    }));
    [self addTeardownBlock:^{
        method_setImplementation(isRunningInAppExtension, originalImp);
    }];

    BugsnagKVStore *kvStore = [BugsnagKVStore new];
    BugsnagSystemState *(^ systemState)() = ^{
        return [[BugsnagSystemState alloc] initWithConfiguration:[[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1]];
    };

    // Debugger active
    
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);
    
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);
    
    // Debugger inactive

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);
    
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertTrue(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:true forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore setBoolean:false forKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
    XCTAssertFalse(systemState().lastLaunchTerminatedUnexpectedly);

    // Delete keys so they don't interfere with other tests.
    [kvStore deleteKey:SYSTEMSTATE_APP_DEBUGGER_IS_ACTIVE];
    [kvStore deleteKey:SYSTEMSTATE_APP_WAS_TERMINATED];
    [kvStore deleteKey:SYSTEMSTATE_APP_IS_ACTIVE];
    [kvStore deleteKey:SYSTEMSTATE_APP_IS_IN_FOREGROUND];
}

@end

