//
//  NSUserDefaultsStub.m
//  Bugsnag
//
//  Created by Nick Dowell on 18/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "NSUserDefaultsStub.h"

#import "BugsnagConfiguration+Private.h"


@implementation NSUserDefaultsStub {
    NSMutableDictionary *_storage;
}

+ (void)load {
    BugsnagConfiguration.userDefaults = (id)[[self alloc] init];
}

- (instancetype)init {
    if ((self = [super init])) {
        _storage = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)objectForKey:(NSString *)defaultName {
    return [_storage objectForKey:defaultName];
}

- (void)removeObjectForKey:(NSString *)defaultName {
    [_storage removeObjectForKey:defaultName];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    [_storage setObject:value forKey:defaultName];
}

@end
