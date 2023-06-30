//
//  FileBasedTest.m
//  BugsnagPerformance-iOS
//
//  Created by Karl Stenerud on 11.01.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import "FileBasedTest.h"

@implementation FileBasedTest

- (NSString *)newPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
}

- (void)setUp {
    self.filePath = [self newPath];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:nil];
}

@end
