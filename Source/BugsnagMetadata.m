//
//  BugsnagMetaData.m
//
//  Created by Conrad Irwin on 2014-10-01.
//
//  Copyright (c) 2014 Bugsnag, Inc. All rights reserved.
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

#import "BugsnagMetadata.h"
#import "BSGSerialization.h"
#import "BugsnagLogger.h"

@interface BugsnagMetadata ()
@property(atomic, strong) NSMutableDictionary *dictionary;
@end

@implementation BugsnagMetadata

- (id)init {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    return [self initWithDictionary:dict];
}

- (id)initWithDictionary:(NSMutableDictionary *)dict {
    if (self = [super init]) {
        self.dictionary = dict;
    }
    [self.delegate metadataChanged:self];
    return self;
}

// MARK: - <NSMutableCopying>

- (id)mutableCopyWithZone:(NSZone *)zone {
    @synchronized(self) {
        NSMutableDictionary *dict = [self.dictionary mutableCopy];
        return [[BugsnagMetadata alloc] initWithDictionary:dict];
    }
}

- (NSMutableDictionary *)getMetadata:(NSString *)sectionName {
    @synchronized(self) {
        return self.dictionary[sectionName];
    }
}

- (NSMutableDictionary *)getMetadata:(NSString *)sectionName
                                 key:(NSString *)key
{
    @synchronized(self) {
        return [self.dictionary valueForKeyPath:[NSString stringWithFormat:@"%@.%@", sectionName, key]];
    }
}

- (void)clearMetadataInSection:(NSString *)sectionName {
    @synchronized(self) {
        [self.dictionary removeObjectForKey:sectionName];
    }
    [self.delegate metadataChanged:self];
}

- (void)clearMetadataInSection:(NSString *)section
                           key:(NSString *)key
{
    @synchronized(self) {
        if ([[[self dictionary] objectForKey:section] objectForKey:key]) {
            [[[self dictionary] objectForKey:section] removeObjectForKey:key];
        }
    }
    [self.delegate metadataChanged:self];
}

- (NSDictionary *)toDictionary {
    @synchronized(self) {
        return [NSDictionary dictionaryWithDictionary:self.dictionary];
    }
}

- (void)addAttribute:(NSString *)attributeName
           withValue:(id)value
       toTabWithName:(NSString *)sectionName
{
    @synchronized(self) {
        if (value) {
            id cleanedValue = BSGSanitizeObject(value);
            if (cleanedValue) {
                NSDictionary *section = [self getMetadata:sectionName];
                if (!section) {
                    section = [NSMutableDictionary new];
                    [[self dictionary] setObject:section forKey:sectionName];
                }
                [section setValue:cleanedValue forKey:attributeName];
            }
            else {
                Class klass = [value class];
                bsg_log_err(@"Failed to add metadata: Value of class %@ is not "
                            @"JSON serializable",
                            klass);
            }
        }
        else {
            [[self getMetadata:sectionName] removeObjectForKey:attributeName];
        }
    }
    [self.delegate metadataChanged:self];
}

@end
