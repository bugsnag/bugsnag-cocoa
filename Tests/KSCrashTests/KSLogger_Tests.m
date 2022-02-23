//
//  KSLogger_Tests.m
//
//  Created by Karl Stenerud on 2013-01-26.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#import <XCTest/XCTest.h>
#import "XCTestCase+KSCrash.h"

#import "BSG_KSLogger.h"


@interface KSLogger_Tests : XCTestCase

@property(nonatomic, readwrite, retain) NSString* tempDir;

@end


@implementation KSLogger_Tests

@synthesize tempDir = _tempDir;

- (void) setUp
{
    [super setUp];
    self.tempDir = [self createTempPath];
}

- (void) tearDown
{
    [self removePath:self.tempDir];
}

- (void) testLogError
{
    BSG_KSLOG_ERROR("TEST");
}

- (void) testLogAlways
{
    BSG_KSLOG_ALWAYS("TEST");
}

- (void) testLogAlwaysNull
{
    BSG_KSLOG_ALWAYS(nil);
}

- (void) testLogBasicError
{
    BSG_KSLOGBASIC_ERROR("TEST");
}

- (void) testLogBasicErrorNull
{
    BSG_KSLOGBASIC_ERROR(nil);
}

- (void) testLogBasicAlways
{
    BSG_KSLOGBASIC_ALWAYS("TEST");
}

- (void) testLogBasicAlwaysNull
{
    BSG_KSLOGBASIC_ALWAYS(nil);
}

- (void) testSetLogFilename
{
    NSString* expected = @"TEST";
    NSString* logFileName = [self.tempDir stringByAppendingPathComponent:@"log.txt"];
    bsg_kslog_setLogFilename([logFileName UTF8String], true);
    BSG_KSLOGBASIC_ALWAYS("TEST");
    bsg_kslog_setLogFilename(nil, true);

    NSError* error = nil;
    NSString* result = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"");
    result = [result componentsSeparatedByString:@"\x0a"][0];
    XCTAssertEqualObjects(result, expected, @"");

    BSG_KSLOGBASIC_ALWAYS("blah blah");
    result = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    result = [result componentsSeparatedByString:@"\x0a"][0];
    XCTAssertNil(error, @"");
    XCTAssertEqualObjects(result, expected, @"");
}

- (void)testTruncatedLogEntries
{
    NSString *logFileName = [self.tempDir stringByAppendingPathComponent:@"log.txt"];
    bsg_kslog_setLogFilename([logFileName UTF8String], true);
    
    const char *loremIpsum =
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc bibendum auctor lo"
    "rem sit amet facilisis. In dictum convallis varius. Nam ut convallis quam, non u"
    "llamcorper neque. Donec vitae imperdiet sapien. In semper convallis nunc nec lao"
    "reet. Praesent lorem neque, sodales at elementum id, luctus et eros. Maecenas te"
    "llus libero, mattis at augue sed, viverra dignissim nibh.\n\nNullam ac mi dictum"
    ", vestibulum velit sed, egestas neque. Nulla mattis eget risus sed hendrerit. Do"
    "nec a mi augue. Morbi vel orci magna. Duis hendrerit gravida nisl eget sodales. "
    "Aenean dignissim lorem dui, at finibus neque sodales nec. Vivamus quis purus lor"
    "em. Morbi lacinia porttitor mauris interdum elementum. Ut vestibulum diam a tell"
    "us pharetra, vitae iaculis erat semper. Aenean consectetur orci turpis, non male"
    "suada tortor congue ac. Duis ac elit in libero scelerisque venenatis quis quis d"
    "ui. Pellentesque sed fringilla nulla, ac eleifend lorem.\n\nNulla in ipsum conva"
    "llis, congue ipsum sed, consequat felis. Nullam ut libero congue, posuere nisl a"
    ", suscipit arcu. Maecenas tincidunt mauris vel tortor tincidunt imperdiet. Nulla"
    "m id urna finibus, condimentum quam ut, consectetur urna. Nunc maximus varius la"
    "cus et fermentum. Pellentesque massa nunc, dignissim et dui id, tempus interdum "
    "tellus. Mauris condimentum eleifend leo in auctor. Nunc molestie sed leo in dign"
    "issim. Suspendisse mattis vestibulum sollicitudin. Proin tristique ipsum nec mol"
    "lis finibus. Etiam tristique est id neque accumsan, ac orci aliquam.\n";
    
    const int line = __LINE__;
    BSG_KSLOG_ALWAYS("%s", loremIpsum);
    BSG_KSLOG_ALWAYS("Testing");
    BSG_KSLOGBASIC_ALWAYS("%s", loremIpsum);
    BSG_KSLOGBASIC_ALWAYS("Testing");

    bsg_kslog_setLogFilename(NULL, true);
    
    NSError *error = nil;
    NSString *contents = [NSString stringWithContentsOfFile:logFileName encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNotNil(contents, @"%@", error);
    
    NSString *expected = [NSString stringWithFormat:@""
                          // Generated with `sed 's/$/\\n/' | tr -d '\n' | fold | sed 's/$/"/' | sed 's/^/"/'`
                          "FORCE: KSLogger_Tests.m:%d: -[KSLogger_Tests testTruncatedLogEntries](): Lorem "
                          "ipsum dolor sit amet, consectetur adipiscing elit. Nunc bibendum auctor lorem si"
                          "t amet facilisis. In dictum convallis varius. Nam ut convallis quam, non ullamco"
                          "rper neque. Donec vitae imperdiet sapien. In semper convallis nunc nec laoreet. "
                          "Praesent lorem neque, sodales at elementum id, luctus et eros. Maecenas tellus l"
                          "ibero, mattis at augue sed, viverra dignissim nibh.\n\nNullam ac mi dictum, vest"
                          "ibulum velit sed, egestas neque. Nulla mattis eget risus sed hendrerit. Donec a "
                          "mi augue. Morbi vel orci magna. Duis hendrerit gravida nisl eget sodales. Aenean"
                          " dignissim lorem dui, at finibus neque sodales nec. Vivamus quis purus lorem. Mo"
                          "rbi lacinia porttitor mauris interdum elementum. Ut vestibulum diam a tellus pha"
                          "retra, vitae iaculis erat semper. Aenean consectetur orci turpis, non malesuada "
                          "tortor congue ac. Duis ac elit in libero scelerisque venenatis quis quis dui. Pe"
                          "llentesque sed fringilla nulla, ac eleifend lorem.\n\nNulla in ipsu\nFORCE: KSLo"
                          "gger_Tests.m:%d: -[KSLogger_Tests testTruncatedLogEntries](): Testing\nLorem ip"
                          "sum dolor sit amet, consectetur adipiscing elit. Nunc bibendum auctor lorem sit "
                          "amet facilisis. In dictum convallis varius. Nam ut convallis quam, non ullamcorp"
                          "er neque. Donec vitae imperdiet sapien. In semper convallis nunc nec laoreet. Pr"
                          "aesent lorem neque, sodales at elementum id, luctus et eros. Maecenas tellus lib"
                          "ero, mattis at augue sed, viverra dignissim nibh.\n\nNullam ac mi dictum, vestib"
                          "ulum velit sed, egestas neque. Nulla mattis eget risus sed hendrerit. Donec a mi"
                          " augue. Morbi vel orci magna. Duis hendrerit gravida nisl eget sodales. Aenean d"
                          "ignissim lorem dui, at finibus neque sodales nec. Vivamus quis purus lorem. Morb"
                          "i lacinia porttitor mauris interdum elementum. Ut vestibulum diam a tellus phare"
                          "tra, vitae iaculis erat semper. Aenean consectetur orci turpis, non malesuada to"
                          "rtor congue ac. Duis ac elit in libero scelerisque venenatis quis quis dui. Pell"
                          "entesque sed fringilla nulla, ac eleifend lorem.\n\nNulla in ipsum convallis, co"
                          "ngue ipsum sed, consequat felis. Nullam ut libero congue, p\nTesting\n",
                          line + 1, line + 2];
    XCTAssertEqualObjects(contents, expected);
}

@end
