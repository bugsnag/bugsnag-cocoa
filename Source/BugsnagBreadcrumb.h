//
//  BugsnagBreadcrumb.h
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
#import <Foundation/Foundation.h>

#ifndef NS_DESIGNATED_INITIALIZER
#if __has_attribute(objc_designated_initializer)
#define NS_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#else
#define NS_DESIGNATED_INITIALIZER
#endif
#endif

typedef NS_ENUM(NSUInteger, BSGBreadcrumbType) {
    /**
     *  Any breadcrumb sent via Bugsnag.leaveBreadcrumb()
     */
    BSGBreadcrumbTypeCustom,
    /**
     *  A call to Bugsnag.notify() (internal use only)
     */
    BSGBreadcrumbTypeError,
    /**
     *  A log message
     */
    BSGBreadcrumbTypeLog,
    /**
     *  A navigation action, such as pushing a view controller or dismissing an
     *  alert
     */
    BSGBreadcrumbTypeNavigation,
    /**
     *  A background process, such performing a database query
     */
    BSGBreadcrumbTypeProcess,
    /**
     *  A network request
     */
    BSGBreadcrumbTypeRequest,
    /**
     *  Change in application or view state
     */
    BSGBreadcrumbTypeState,
    /**
     *  A user event, such as authentication or control events
     */
    BSGBreadcrumbTypeUser,
};

@interface BugsnagBreadcrumb : NSObject

@property(readonly, nonatomic, nullable) NSDate *timestamp;
@property(readonly) BSGBreadcrumbType type;
@property(readonly, nonatomic, copy, nonnull) NSString *name;
@property(readonly, nonatomic, copy, nonnull) NSDictionary *metadata;

- (instancetype _Nullable)initWithMessage:(NSString *_Nullable)message
                                timestamp:(NSDate *_Nullable)date
    NS_DESIGNATED_INITIALIZER;

- (instancetype _Nullable)initWithName:(NSString *_Nonnull)name
                             timestamp:(NSDate *_Nonnull)date
                                  type:(BSGBreadcrumbType)type
                              metadata:(NSDictionary *_Nullable)metadata
    NS_DESIGNATED_INITIALIZER;

@end

@interface BugsnagBreadcrumbs : NSObject

/**
 * The maximum number of breadcrumbs. Resizable. Must be called from the
 * main thread.
 */
@property(assign, nonatomic, readwrite) NSUInteger capacity;

/** Number of breadcrumbs accumulated */
@property(assign, readonly) NSUInteger count;

/**
 * Store a new breadcrumb with a provided message. Must be called from the
 * main thread.
 */
- (void)addBreadcrumb:(NSString *_Nonnull)breadcrumbMessage;

/**
 * Clear all stored breadcrumbs. Must be called from the main thread.
 */
- (void)clearBreadcrumbs;

/** Breadcrumb object for a particular index or nil */
- (BugsnagBreadcrumb *_Nullable)objectAtIndexedSubscript:(NSUInteger)index;

/**
 * Serializable array representation of breadcrumbs, represented as nested
 * strings in the format:
 * [[timestamp,message]...]
 *
 * returns nil if empty
 */
- (NSArray *_Nullable)arrayValue;

@end
