//
//  BugsnagMetadata.m
//  bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagMetaData.h"

void mergeDictionaries(NSMutableDictionary *destination, NSDictionary *source) {
    [source enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop) {
        if ([destination objectForKey:key] && [value isKindOfClass:[NSDictionary class]]) {
            [[destination objectForKey: key] mergeWith: (NSDictionary *) value];
        } else {
            [destination setObject: value forKey: key];
        }
    }];
}

@interface BugsnagMetaData ()
@property (atomic, strong) NSMutableDictionary *dictionary;
@end

@implementation BugsnagMetaData

- (id) init {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    return [self initWithDictionary:dict];
}

- (id) initWithDictionary:(NSMutableDictionary*)dict {
    if(self = [super init]) {
        self.dictionary = dict;
    }
    return self;
}

- (id) mutableCopyWithZone:(NSZone *)zone {
    @synchronized(self) {
        NSMutableDictionary *dict = [self.dictionary mutableCopy];
        return [[BugsnagMetaData alloc] initWithDictionary:dict];
    }
}

- (NSMutableDictionary *) getTab:(NSString*)tabName {
    @synchronized(self) {
        NSMutableDictionary *tab = [self.dictionary objectForKey:tabName];
        if(!tab) {
            tab = [NSMutableDictionary dictionary];
            [self.dictionary setObject:tab forKey:tabName];
        }
        return tab;
    }
}

- (void) clearTab:(NSString*)tabName {
    @synchronized(self) {
        [self.dictionary removeObjectForKey:tabName];
    }
}

- (void) mergeWith:(NSDictionary*)data {
    @synchronized(self) {
        [data enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                mergeDictionaries([self getTab:key], value);
            } else {
                [[self getTab:@"customData"] setObject: value forKey: key];
            }
        }];
    }
}

- (NSDictionary*) toDictionary {
    @synchronized(self) {
        return [NSDictionary dictionaryWithDictionary:self.dictionary];
    }
}

- (NSDictionary *) toDescriptionDictionary {
    id (^convertValue)(id);
    __block __weak id (^weak_convertValue)(id) = convertValue = ^(id value) {
        if ([value isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *dictionary = [NSMutableDictionary new];
            [value enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                dictionary[key] = weak_convertValue(obj);
            }];
            return (id)dictionary;
        }
        else if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *array = [NSMutableArray new];
            [value enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [array addObject:weak_convertValue(obj)];
            }];
            return (id)array;
        }
        else if ([value isKindOfClass:[NSString class]]
                 || [value isKindOfClass:[NSData class]]
                 || [value isKindOfClass:[NSDate class]]
                 || [value isKindOfClass:[NSNumber class]]) {
            return (id)value;
        }
        else {
            return (id)[value description];
        }
    };

    @synchronized(self) {
        NSMutableDictionary *convertedDictionary = [NSMutableDictionary new];
        [self.dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            convertedDictionary[key] = convertValue(obj);
        }];
        return [NSDictionary dictionaryWithDictionary:convertedDictionary];
    }
}

- (void) addAttribute:(NSString*)attributeName withValue:(id)value toTabWithName:(NSString*)tabName {
    @synchronized(self) {
        if(value) {
            [[self getTab:tabName] setObject:value forKey:attributeName];
        } else {
            [[self getTab:tabName] removeObjectForKey:attributeName];
        }
    }
}

@end