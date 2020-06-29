//
//  BugsnagErrorTest.m
//  Tests
//
//  Created by Jamie Lynch on 08/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagKeys.h"
#import "BugsnagError.h"
#import "BugsnagStackframe.h"
#import "BugsnagThread.h"

NSString *_Nonnull BSGParseErrorClass(NSDictionary *error, NSString *errorType);

NSString *BSGParseErrorMessage(NSDictionary *report, NSDictionary *error, NSString *errorType);

@interface BugsnagError ()
- (instancetype)initWithEvent:(NSDictionary *)event errorReportingThread:(BugsnagThread *)thread;

- (NSDictionary *)toDictionary;
@end

@interface BugsnagThread ()
+ (NSMutableArray<BugsnagThread *> *)threadsFromArray:(NSArray *)threads
                                         binaryImages:(NSArray *)binaryImages
                                                depth:(NSUInteger)depth
                                            errorType:(NSString *)errorType;
@end

@interface BugsnagErrorTest : XCTestCase
@property NSDictionary *event;
@end

@implementation BugsnagErrorTest

- (void)setUp {
    self.event = [self generateEvent:@{}];
}

- (NSDictionary *)generateEvent:(NSDictionary *)notableAddresses {
    NSDictionary *thread = @{
            @"current_thread": @YES,
            @"crashed": @YES,
            @"index": @4,
            @"backtrace": @{
                    @"skipped": @0,
                    @"contents": @[
                            @{
                                    @"symbol_name": @"kscrashsentry_reportUserException",
                                    @"symbol_addr": @4491038467,
                                    @"instruction_addr": @4491038575,
                                    @"object_name": @"CrashProbeiOS",
                                    @"object_addr": @4490747904
                            }
                    ]
            },
            @"notable_addresses": notableAddresses
    };
    NSDictionary *binaryImage = @{
            @"uuid": @"D0A41830-4FD2-3B02-A23B-0741AD4C7F52",
            @"image_vmaddr": @4294967296,
            @"image_addr": @4490747904,
            @"image_size": @483328,
            @"name": @"/Users/joesmith/foo",
    };
    return @{
            @"crash": @{
                    @"error": @{
                            @"type": @"user",
                            @"user_reported": @{
                                    @"name": @"Foo Exception"
                            },
                            @"reason": @"Foo overload"
                    },
                    @"threads": @[thread],
            },
            @"binary_images": @[binaryImage]
    };
}

- (void)testErrorLoad {
    BugsnagThread *thread = [self findErrorReportingThread:self.event];
    BugsnagError *error = [[BugsnagError alloc] initWithEvent:self.event errorReportingThread:thread];
    XCTAssertEqualObjects(@"Foo Exception", error.errorClass);
    XCTAssertEqualObjects(@"Foo overload", error.errorMessage);
    XCTAssertEqual(BSGErrorTypeCocoa, error.type);

    XCTAssertEqual(1, [error.stacktrace count]);
    BugsnagStackframe *frame = error.stacktrace[0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame.method);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame.machoFile);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame.machoUuid);
}

- (void)testToDictionary {
    BugsnagThread *thread = [self findErrorReportingThread:self.event];
    BugsnagError *error = [[BugsnagError alloc] initWithEvent:self.event errorReportingThread:thread];
    NSDictionary *dict = [error toDictionary];
    XCTAssertEqualObjects(@"Foo Exception", dict[@"errorClass"]);
    XCTAssertEqualObjects(@"Foo overload", dict[@"message"]);
    XCTAssertEqualObjects(@"cocoa", dict[@"type"]);

    XCTAssertEqual(1, [dict[@"stacktrace"] count]);
    NSDictionary *frame = dict[@"stacktrace"][0];
    XCTAssertEqualObjects(@"kscrashsentry_reportUserException", frame[@"method"]);
    XCTAssertEqualObjects(@"D0A41830-4FD2-3B02-A23B-0741AD4C7F52", frame[@"machoUUID"]);
    XCTAssertEqualObjects(@"/Users/joesmith/foo", frame[@"machoFile"]);
}

- (BugsnagThread *)findErrorReportingThread:(NSDictionary *)event {
    NSArray *binaryImages = event[@"binary_images"];
    NSArray *threadDict = [event valueForKeyPath:@"crash.threads"];
    NSArray<BugsnagThread *> *threads = [BugsnagThread threadsFromArray:threadDict
                                                           binaryImages:binaryImages
                                                                  depth:0
                                                              errorType:@"user"];
    for (BugsnagThread *thread in threads) {
        if (thread.errorReportingThread) {
            return thread;
        }
    }
    return nil;
}

/**
 * If notable addresses are in the event, the error message/class should be enhanced
 * with these values
 */
- (void)testMessageEnhancement {
    self.event = [self generateEvent:@{
            @"x9": @{
                    @"address": @4511086448,
                    @"type": @"string",
                    @"value": @"Something went wrong"
            },
            @"r16": @{
                    @"address": @4511089532,
                    @"type": @"string",
                    @"value": @"Fatal error"
            }
    }];
    BugsnagError *error = [[BugsnagError alloc] initWithEvent:self.event errorReportingThread:nil];
    NSDictionary *dict = [error toDictionary];
    XCTAssertEqualObjects(@"Fatal error", dict[@"errorClass"]);
    XCTAssertEqualObjects(@"Something went wrong", dict[@"message"]);
}

- (void) testEmptyErrorDataFromThreads {
    self.event = [self generateEvent:@{
            @"x9": @{
                    @"address": @4511086448,
                    @"type": @"string",
                    @"value": @"Something went wrong"
            },
            @"r16": @{
                    @"address": @4511089532,
                    @"type": @"string",
                    @"value": [NSNull null]
            }
    }];
    BugsnagError *error = [[BugsnagError alloc] initWithEvent:self.event errorReportingThread:nil];
    NSDictionary *dict = [error toDictionary];
    XCTAssertEqualObjects(@"Foo Exception", dict[@"errorClass"]);
    XCTAssertEqualObjects(@"Foo overload", dict[@"message"]);
}

- (void)testErrorClassParse {
    XCTAssertEqualObjects(@"foo", BSGParseErrorClass(@{@"cpp_exception": @{@"name": @"foo"}}, @"cpp_exception"));
    XCTAssertEqualObjects(@"bar", BSGParseErrorClass(@{@"mach": @{@"exception_name": @"bar"}}, @"mach"));
    XCTAssertEqualObjects(@"wham", BSGParseErrorClass(@{@"signal": @{@"name": @"wham"}}, @"signal"));
    XCTAssertEqualObjects(@"zed", BSGParseErrorClass(@{@"nsexception": @{@"name": @"zed"}}, @"nsexception"));
    XCTAssertEqualObjects(@"ooh", BSGParseErrorClass(@{@"user_reported": @{@"name": @"ooh"}}, @"user"));
    XCTAssertEqualObjects(@"Exception", BSGParseErrorClass(@{}, @"some-val"));
}

- (void)testErrorMessageParse {
    XCTAssertEqualObjects(@"", BSGParseErrorMessage(@{}, @{}, @""));
    XCTAssertEqualObjects(@"foo", BSGParseErrorMessage(@{}, @{@"reason": @"foo"}, @""));

    XCTAssertEqualObjects(@"Exception", BSGParseErrorMessage(@{
            @"crash": @{
                    @"diagnosis": @"Exception"
            }
    }, @{}, @"signal"));

    XCTAssertEqualObjects(@"Exceptional circumstance", BSGParseErrorMessage(@{
            @"crash": @{
                    @"diagnosis": @"Exceptional circumstance\ntest"
            }
    }, @{}, @"mach"));

    XCTAssertEqualObjects(@"", BSGParseErrorMessage(@{
            @"crash": @{
                    @"diagnosis": @"No diagnosis foo"
            }
    }, @{}, @"mach"));
}

- (void)testStacktraceOverride {
    BugsnagThread *thread = [self findErrorReportingThread:self.event];
    BugsnagError *error = [[BugsnagError alloc] initWithEvent:self.event errorReportingThread:thread];
    XCTAssertNotNil(error.stacktrace);
    XCTAssertEqual(1, error.stacktrace.count);
    error.stacktrace = @[];
    XCTAssertEqual(0, error.stacktrace.count);
}

@end
