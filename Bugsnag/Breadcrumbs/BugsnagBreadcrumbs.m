//
//  BugsnagBreadcrumbs.m
//  Bugsnag
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//


#import "BugsnagBreadcrumbs.h"

#import "BugsnagLogger.h"
#import "Private.h"
#import "BSGJSONSerialization.h"

@interface BugsnagConfiguration ()
@property(nonatomic) NSMutableArray *onBreadcrumbBlocks;
@end

@interface BugsnagBreadcrumb ()
+ (instancetype _Nullable)breadcrumbWithBlock:
    (BSGBreadcrumbConfiguration _Nonnull)block;
+ (instancetype _Nullable)breadcrumbFromDict:(NSDictionary *_Nonnull)dict;
@end

@interface BugsnagBreadcrumbs ()
@property BugsnagConfiguration *config;
@end

#pragma mark -

@implementation BugsnagBreadcrumbs

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)config {
    static NSString *const BSGBreadcrumbCacheFileName = @"bugsnag_breadcrumbs.json";
    if (self = [super init]) {
        _config = config;
        _breadcrumbs = [NSMutableArray arrayWithCapacity:config.maxBreadcrumbs];
        _readWriteQueue = dispatch_queue_create("com.bugsnag.BreadcrumbRead",
                                                DISPATCH_QUEUE_SERIAL);
        NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(
                                 NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        if (cacheDir != nil) {
            _cachePath = [cacheDir stringByAppendingPathComponent:
                             BSGBreadcrumbCacheFileName];
        }
    }
    return self;
}

- (void)addBreadcrumb:(NSString *)breadcrumbMessage {
    [self addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.message = breadcrumbMessage;
    }];
}

- (void)addBreadcrumbWithBlock:(BSGBreadcrumbConfiguration)block {
    if (self.config.maxBreadcrumbs == 0) {
        return;
    }
    BugsnagBreadcrumb *crumb = [BugsnagBreadcrumb breadcrumbWithBlock:block];
    if (crumb != nil && [self shouldSendBreadcrumb:crumb]) {
        dispatch_barrier_sync(self.readWriteQueue, ^{
            if ((self.breadcrumbs.count > 0) &&
                (self.breadcrumbs.count == self.config.maxBreadcrumbs)) {
                [self.breadcrumbs removeObjectAtIndex:0];
            }
            [self.breadcrumbs addObject:crumb];
            // Serialize crumbs to disk inside barrier to avoid simultaneous
            // access to the file
            if (self.cachePath != nil) {
                static NSString *const arrayKeyPath = @"objectValue";
                NSArray *items = [self.breadcrumbs valueForKeyPath:arrayKeyPath];
                if ([BSGJSONSerialization isValidJSONObject:items]) {
                    NSError *error = nil;
                    NSData *data = [BSGJSONSerialization dataWithJSONObject:items
                                                                   options:0
                                                                     error:&error];
                    [data writeToFile:self.cachePath atomically:NO];
                    if (error != nil) {
                        bsg_log_err(@"Failed to write breadcrumbs to disk: %@", error);
                    }
                }
            }
        });
    }
}

- (BOOL)shouldSendBreadcrumb:(BugsnagBreadcrumb *)crumb {
    for (BugsnagOnBreadcrumbBlock block in self.config.onBreadcrumbBlocks) {
        @try {
            if (!block(crumb)) {
                return NO;
            }
        } @catch (NSException *exception) {
            bsg_log_err(@"Error from onBreadcrumb callback: %@", exception);
        }
    }
    return YES;
}

- (nullable NSArray<NSDictionary *> *)cachedBreadcrumbs {
    __block NSArray *cache = nil;
    dispatch_barrier_sync(self.readWriteQueue, ^{
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:self.cachePath options:0 error:&error];
        if (error == nil) {
            cache = [BSGJSONSerialization JSONObjectWithData:data options:0 error:&error];
        }
        if (error != nil) {
            bsg_log_err(@"Failed to read breadcrumbs from disk: %@", error);
        }
    });
    return [cache isKindOfClass:[NSArray class]] ? cache : nil;
}

- (NSArray<BugsnagBreadcrumb *> *)getBreadcrumbs {
    __block NSArray *result = nil;
    dispatch_barrier_sync(self.readWriteQueue, ^{
        result = [NSArray arrayWithArray:self.breadcrumbs];
    });
    return result;
}

@end
