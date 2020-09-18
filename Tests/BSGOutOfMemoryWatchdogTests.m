#import <XCTest/XCTest.h>
#import "BSGOutOfMemoryWatchdog.h"
#import "BSG_KSSystemInfo.h"
#import "BugsnagConfiguration.h"
#import "Bugsnag.h"
#import "BugsnagClient.h"
#import "BugsnagTestConstants.h"
#import "BugsnagKVStoreObjC.h"

// Expose private identifiers for testing
@interface BSGOutOfMemoryWatchdog(Test)
- (NSDictionary *)readSentinelFile;
- (void)writeSentinelFile;
@end

@interface Bugsnag (Testing)
+ (BugsnagClient *)client;
@end

@interface BugsnagClient (Testing)
@property (nonatomic, strong) BSGOutOfMemoryWatchdog *oomWatchdog;
@property (nonatomic) NSString *codeBundleId;
@end

@interface BugsnagClient ()
- (void)start;
@end

@interface BSGOutOfMemoryWatchdog (Testing)
- (NSMutableDictionary *)generateCacheInfoWithConfig:(BugsnagConfiguration *)config;
@property(nonatomic, strong, readwrite) NSMutableDictionary *cachedFileInfo;
@end

@interface BSGOutOfMemoryWatchdogTests : XCTestCase
@end

@implementation BSGOutOfMemoryWatchdogTests

- (BugsnagClient *)newClient {
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];
    config.autoDetectErrors = NO;
    config.releaseStage = @"MagicalTestingTime";

    return [[BugsnagClient alloc] initWithConfiguration:config];
}

- (void)testNilPathDoesNotCreateWatchdog {
    XCTAssertNil([[BSGOutOfMemoryWatchdog alloc] init]);
    XCTAssertNil([[BSGOutOfMemoryWatchdog alloc] initWithSentinelPath:nil
                                                        configuration:nil]);
}

/**
 * Test that the generated OOM report values exist and are correct (where that can be tested)
 */
- (void)testOOMFieldsSetCorrectly {
    BugsnagClient *client = [self newClient];
    BSGOutOfMemoryWatchdog *watchdog = [client oomWatchdog];

    client.codeBundleId = @"codeBundleIdHere";
    NSMutableDictionary *cachedFileInfo = [watchdog cachedFileInfo];
    XCTAssertNotNil([cachedFileInfo objectForKey:@"app"]);
    XCTAssertNotNil([cachedFileInfo objectForKey:@"device"]);
    
    NSMutableDictionary *app = [cachedFileInfo objectForKey:@"app"];
    XCTAssertNotNil([app objectForKey:@"bundleVersion"]);
    XCTAssertNotNil([app objectForKey:@"id"]);
    XCTAssertNotNil([app objectForKey:@"inForeground"]);
    XCTAssertNotNil([app objectForKey:@"version"]);
    XCTAssertNotNil([app objectForKey:@"name"]);
    XCTAssertEqualObjects([app valueForKey:@"codeBundleId"], @"codeBundleIdHere");
    XCTAssertEqualObjects([app valueForKey:@"releaseStage"], @"MagicalTestingTime");
    
    NSMutableDictionary *device = [cachedFileInfo objectForKey:@"device"];
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
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:DUMMY_APIKEY_32CHAR_1];

    BSGOutOfMemoryWatchdog *watchdog = [[BSGOutOfMemoryWatchdog alloc] initWithSentinelPath:tempFilePath configuration:config];
    watchdog.cachedFileInfo[@1] = @"a";
    [watchdog writeSentinelFile];
    NSError* error;
    [@"{1=\"a\"" writeToFile:tempFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);
    [watchdog readSentinelFile];
}

#define KV_KEY_IS_MONITORING_OOM @"oom-isMonitoringOOM"
#define KV_KEY_IS_ACTIVE @"oom-isActive"
#define KV_KEY_IS_IN_FOREGROUND @"oom-isInForeground"

-(void)testOOM {
    BugsnagClient *client = nil;
    BugsnagKVStore *kvStore = [BugsnagKVStore new];

    [kvStore setBoolean:true forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:true forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:true forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertTrue([client.oomWatchdog didOOMLastLaunch]);

    [kvStore setBoolean:true forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:false forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:true forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertFalse([client.oomWatchdog didOOMLastLaunch]);

    [kvStore setBoolean:true forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:true forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:false forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertFalse([client.oomWatchdog didOOMLastLaunch]);
    
    [kvStore setBoolean:false forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:true forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:true forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertFalse([client.oomWatchdog didOOMLastLaunch]);

    [kvStore setBoolean:false forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:false forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:true forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertFalse([client.oomWatchdog didOOMLastLaunch]);

    [kvStore setBoolean:false forKey:KV_KEY_IS_MONITORING_OOM];
    [kvStore setBoolean:true forKey:KV_KEY_IS_ACTIVE];
    [kvStore setBoolean:false forKey:KV_KEY_IS_IN_FOREGROUND];
    client = [self newClient];
    XCTAssertFalse([client.oomWatchdog didOOMLastLaunch]);
}

@end

