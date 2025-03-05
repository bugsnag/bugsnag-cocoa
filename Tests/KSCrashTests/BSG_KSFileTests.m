//
//  KSFileTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 13/01/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "KSFile.h"

@interface KSFileTests : XCTestCase

@property NSString *filePath;
@property int fileDescriptor;

@end

@implementation KSFileTests

- (void)setUp {
    [super setUp];
    self.filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[self description]];
    self.fileDescriptor = open(self.filePath.fileSystemRepresentation, O_RDWR | O_CREAT | O_EXCL, 0644);
}

- (void)tearDown {
    close(self.fileDescriptor);
    unlink(self.filePath.fileSystemRepresentation);
}

- (void)testFileWrite {
    KSFile file;
    const size_t bufferSize = 8;
    char buffer[bufferSize];
    
    KSFileInit(&file, self.fileDescriptor, buffer, bufferSize);
    XCTAssertEqual(file.bufferSize, bufferSize);
    XCTAssertEqual(file.bufferUsed, 0);
    
    KSFileWrite(&file, "Someone", 7);
    XCTAssertEqual(file.bufferUsed, 7, @"The buffer should not be flushed until filled");
    KSFileWrite(&file, " ", 1);
    XCTAssertEqual(file.bufferUsed, 0, @"The buffer should be flushed once filled");
    
    KSFileWrite(&file, "says", 4);
    KSFileWrite(&file, ": ", 2);
    XCTAssertEqual(file.bufferUsed, 6, @"The buffer should not be flushed until filled");
    
    KSFileWrite(&file, "Hello, ", 7);
    XCTAssertEqual(file.bufferUsed, (6 + 7) % bufferSize);
    
    KSFileWrite(&file, "Supercalifragilisticexpialidocious", 34);
    XCTAssertEqual(file.bufferUsed, 0, @"Large writes should flush the buffer and leave it empty");
    
    KSFileFlush(&file);
    XCTAssertEqualObjects([self fileContentsAsString], @"Someone says: Hello, Supercalifragilisticexpialidocious");
}

- (NSString *)fileContentsAsString {
    return [NSString stringWithContentsOfFile:self.filePath encoding:NSUTF8StringEncoding error:nil];
}

@end
