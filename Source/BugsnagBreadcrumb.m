//
//  BugsnagBreadcrumb.m
//
//  Created by Delisa Mason on 9/16/15.
//
//  Copyright (c) 2015 Bugsnag, Inc. All rights reserved.
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
#import "BugsnagBreadcrumb.h"
#import "Bugsnag.h"

@interface BugsnagBreadcrumbs()

@property (nonatomic,readwrite,strong) NSMutableArray* breadcrumbs;
@end

@implementation BugsnagBreadcrumb

- (instancetype)init {
    self = [self initWithMessage:nil timestamp:nil];
    return self;
}

- (instancetype)initWithMessage:(NSString *)message timestamp:(NSDate *)date {
    if (message.length == 0)
        return nil;

    if (self = [super init]) {
        _message = [message copy];
        _timestamp = date;
    }
    return self;
}

@end

@implementation BugsnagBreadcrumbs

NSUInteger BreadcrumbsDefaultCapacity = 20;

- (instancetype)init {
    if (self = [super init]) {
        _breadcrumbs = [NSMutableArray new];
        _capacity = BreadcrumbsDefaultCapacity;
    }
    return self;
}

- (void)addBreadcrumb:(NSString *)breadcrumbMessage {
    NSAssert([[NSThread currentThread] isMainThread], @"Breadcrumbs must be mutated on the main thread.");
    if (self.capacity == 0) {
        return;
    }
    BugsnagBreadcrumb* crumb = [[BugsnagBreadcrumb alloc] initWithMessage:breadcrumbMessage timestamp:[NSDate date]];
    if (crumb) {
        [self resizeToFitCapacity:self.capacity - 1];
        [self.breadcrumbs addObject:crumb];
    }
}

- (void)setCapacity:(NSUInteger)capacity {
    NSAssert([[NSThread currentThread] isMainThread], @"Breadcrumbs must be mutated on the main thread.");
    if (capacity == _capacity) {
        return;
    }
    [self resizeToFitCapacity:capacity];
    [self willChangeValueForKey:NSStringFromSelector(@selector(capacity))];
    _capacity = capacity;
    [self didChangeValueForKey:NSStringFromSelector(@selector(capacity))];
}

- (void)clearBreadcrumbs {
    NSAssert([[NSThread currentThread] isMainThread], @"Breadcrumbs must be mutated on the main thread.");
    [self.breadcrumbs removeAllObjects];
}

- (NSUInteger)count {
    return self.breadcrumbs.count;
}

- (BugsnagBreadcrumb *)objectAtIndexedSubscript:(NSUInteger)index {
    if (index < [self count]) {
        return self.breadcrumbs[index];
    }
    return nil;
}

- (NSArray *)arrayValue {
    if ([self count] == 0) {
        return nil;
    }
    NSMutableArray* contents = [[NSMutableArray alloc] initWithCapacity:[self count]];
    for (BugsnagBreadcrumb* crumb in self.breadcrumbs) {
        NSString* timestamp = [[Bugsnag payloadDateFormatter] stringFromDate:crumb.timestamp];
        if (timestamp && crumb.message.length > 0) {
            [contents addObject:@[timestamp,crumb.message]];
        }
    }
    return contents;
}

- (void)resizeToFitCapacity:(NSUInteger)capacity {
    if (capacity == 0) {
        [self clearBreadcrumbs];
        return;
    }
    while ([self count] > capacity) {
        [self.breadcrumbs removeObjectAtIndex:0];
    }
}

@end