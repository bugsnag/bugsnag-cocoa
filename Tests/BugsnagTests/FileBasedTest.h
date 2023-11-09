//
//  FileBasedTest.h
//  BugsnagPerformance-iOS
//
//  Created by Karl Stenerud on 11.01.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import "BSGTestCase.h"

@interface FileBasedTest : BSGTestCase

@property(readwrite, nonatomic) NSString *filePath;

- (NSString *)newPath;

@end
