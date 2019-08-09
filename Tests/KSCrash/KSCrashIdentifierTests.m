#import <XCTest/XCTest.h>
#import <string.h>
#import "BSG_KSCrashIdentifier.h"

@interface KSCrashIdentifierTests : XCTestCase
@end

@implementation KSCrashIdentifierTests

- (void)testGenerateUniqueIDs {
    char *id1 = (char *)bsg_kscrash_generate_report_identifier();
    char *id2 = (char *)bsg_kscrash_generate_report_identifier();
    char *id3 = (char *)bsg_kscrash_generate_report_identifier();
    XCTAssertNotEqual(0, strcmp(id1, id2));
    XCTAssertNotEqual(0, strcmp(id1, id3));
    XCTAssertNotEqual(0, strcmp(id2, id3));
    free(id1);
    free(id2);
    free(id3);
}

- (void)testIsUUID {
    char *id1 = (char *)bsg_kscrash_generate_report_identifier();
    NSString *uuidString = [[NSString alloc] initWithUTF8String:id1];
    XCTAssertNotEqual(0, uuidString.length);

    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    XCTAssertEqual(0, strcmp(id1, [[uuid UUIDString] UTF8String]));
    free(id1);
}

@end
