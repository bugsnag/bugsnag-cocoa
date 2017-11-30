//
// Created by Jamie Lynch on 30/11/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionFileStore.h"

static NSString *const kSessionStoreSuffix = @"-Session-";

@implementation BugsnagSessionFileStore

+ (BugsnagSessionFileStore *)storeWithPath:(NSString *)path {
    return [[self alloc] initWithPath:path
                       filenameSuffix:kSessionStoreSuffix];
}

@end