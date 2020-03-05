#import <XCTest/XCTest.h>

#import "BSGConnectivity.h"

BOOL BSGConnectivityShouldReportChange(SCNetworkReachabilityFlags flags);

NSString *BSGConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags);

void BSGConnectivityCallback(SCNetworkReachabilityRef target,
                                    SCNetworkReachabilityFlags flags,
                                    void *info);

@interface BSGConnectivity ()

+ (BOOL)isValidHostname:(NSString *)host;
@end

@interface BSGConnectivityTest : XCTestCase
@end

@implementation BSGConnectivityTest

- (void)tearDown {
    // Reset connectivity state cache
    BSGConnectivityShouldReportChange(0);
    [BSGConnectivity stopMonitoring];
}

- (void)testConnectivityRepresentations {
    XCTAssertEqualObjects(@"none", BSGConnectivityFlagRepresentation(0));
    XCTAssertEqualObjects(@"none", BSGConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsDirect));
    #if TARGET_OS_TV || TARGET_OS_IPHONE
        // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
        XCTAssertEqualObjects(@"none", BSGConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN));
        XCTAssertEqualObjects(@"cellular", BSGConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable));
    #endif
    XCTAssertEqualObjects(@"wifi", BSGConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable));
    XCTAssertEqualObjects(@"wifi", BSGConnectivityFlagRepresentation(kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));
}

- (void)testShouldReportChange {
    // Duplicate invocation should be false
    XCTAssertFalse(BSGConnectivityShouldReportChange(kSCNetworkReachabilityFlagsReachable));
    // Different invocation but with flags we don't care about should be false
    XCTAssertFalse(BSGConnectivityShouldReportChange(kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsDirect));

    #if TARGET_OS_TV || TARGET_OS_IPHONE
    XCTAssertTrue(BSGConnectivityShouldReportChange(kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsWWAN));
    #endif
    XCTAssertTrue(BSGConnectivityShouldReportChange(0));
}

- (void)testValidHost {
    XCTAssertTrue([BSGConnectivity isValidHostname:@"example.com"]);
    // Could be an internal network hostname
    XCTAssertTrue([BSGConnectivity isValidHostname:@"foo"]);

    // Definitely will not work as expected
    XCTAssertFalse([BSGConnectivity isValidHostname:@""]);
    XCTAssertFalse([BSGConnectivity isValidHostname:nil]);
    XCTAssertFalse([BSGConnectivity isValidHostname:@"localhost"]);
    XCTAssertFalse([BSGConnectivity isValidHostname:@"127.0.0.1"]);
    XCTAssertFalse([BSGConnectivity isValidHostname:@"::1"]);
}

#if TARGET_OS_TV || TARGET_OS_IPHONE
- (void)testCallbackInvokedForSignificantChange {
    __block NSUInteger timesCalled = 0;
    __block NSString *description = nil;
    [self mockMonitorURLWithCallback:^(BOOL connected, NSString * typeDescription, void * info) {
        if (info) {
            timesCalled++;
            description = typeDescription;
        }
    }];
    // Changes should not be immediately reported
    XCTAssertEqual(0, timesCalled);

    // Ignore very first call to change block as "in real life" the first
    // invocation is a false positive
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable];
    XCTAssertEqual(0, timesCalled);

    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsIsWWAN];
    XCTAssertEqual(1, timesCalled);
    XCTAssertEqualObjects(@"cellular", description);

    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable];
    XCTAssertEqual(2, timesCalled);
    XCTAssertEqualObjects(@"wifi", description);

    // No change
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionOnDemand];
    XCTAssertEqual(2, timesCalled);

    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsIsWWAN];
    XCTAssertEqual(3, timesCalled);
    XCTAssertEqualObjects(@"none", description);

    // Insignificant change
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsConnectionOnDemand];
    XCTAssertEqual(3, timesCalled);
}
#else
- (void)testCallbackInvokedForSignificantChange {
    __block NSUInteger timesCalled = 0;
    __block NSString *description = nil;
    [self mockMonitorURLWithCallback:^(BOOL connected, NSString * typeDescription) {
        timesCalled++;
        description = typeDescription;
    }];
    // Changes should not be immediately reported
    XCTAssertEqual(0, timesCalled);

    // Ignore very first call to change block as "in real life" the first
    // invocation is a false positive
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable];
    XCTAssertEqual(0, timesCalled);

    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsIsDirect];
    XCTAssertEqual(1, timesCalled);
    XCTAssertEqualObjects(@"none", description);

    // No change
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsIsDirect];
    XCTAssertEqual(1, timesCalled);

    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable];
    XCTAssertEqual(2, timesCalled);
    XCTAssertEqualObjects(@"wifi", description);

    // Insignificant change
    [self simulateConnectivityChangeTo:kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionOnDemand];
    XCTAssertEqual(2, timesCalled);
}
#endif

- (void)mockMonitorURLWithCallback:(BSGConnectivityChangeBlock)block {
    [BSGConnectivity monitorURL:[NSURL URLWithString:@"cw://definitely.fake.url.seriously"]
                  usingCallback:block];
}

- (void)simulateConnectivityChangeTo:(SCNetworkReachabilityFlags) flags {
    BSGConnectivityCallback(nil, flags, "Unit Test");
}

@end
