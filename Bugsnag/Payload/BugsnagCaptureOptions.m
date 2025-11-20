//
//  BugsnagCaptureOptions.m
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 28/10/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#include <Bugsnag/BugsnagCaptureOptions.h>

@interface BugsnagErrorOptions ()
@end

@implementation BugsnagErrorOptions

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    self.capture = [[BugsnagCaptureOptions alloc] init];
    return self;
}

@end

@interface BugsnagCaptureOptions ()
@end

@implementation BugsnagCaptureOptions

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }

    self.breadcrumbs = TRUE;
    self.featureFlags = TRUE;
    self.metadata = nil;
    self.stacktrace = TRUE;
    self.threads = TRUE;
    self.user = TRUE;

    return self;
}

@end
