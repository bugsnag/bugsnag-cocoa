//
//  BugsnagBreadcrumbs.h
//  Bugsnag
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagBreadcrumb;
@class BugsnagConfiguration;

typedef void (^BSGBreadcrumbConfiguration)(BugsnagBreadcrumb *_Nonnull);

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagBreadcrumbs : NSObject

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)config;

/**
 * Path where breadcrumbs are persisted on disk
 */
@property (nonatomic, readonly, strong, nullable) NSString *cachePath;

/**
 * Store a new breadcrumb with a provided message.
 */
- (void)addBreadcrumb:(NSString *)breadcrumbMessage;

/**
 *  Store a new breadcrumb configured via block.
 *
 *  @param block configuration block
 */
- (void)addBreadcrumbWithBlock:(BSGBreadcrumbConfiguration)block;

/**
 * Returns an array containing the current buffer of breadcrumbs.
 */
- (NSArray<BugsnagBreadcrumb *> *)getBreadcrumbs;

/**
 * Returns the breadcrumb JSON dictionaries stored on disk.
 */
- (nullable NSArray<NSDictionary *> *)cachedBreadcrumbs;

#pragma mark - Private

@property (nonatomic, readonly, strong) NSMutableArray<BugsnagBreadcrumb *> *breadcrumbs;

@property (nonatomic, readonly, strong) dispatch_queue_t readWriteQueue;

@end

NS_ASSUME_NONNULL_END
