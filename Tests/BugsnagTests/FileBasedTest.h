//
//  FileBasedTest.h
//  BugsnagPerformance-iOS
//
//  Created by Karl Stenerud on 11.01.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface FileBasedTest : XCTestCase

@property(readwrite, nonatomic) NSString *filePath;

- (NSString *)newPath;

@end
