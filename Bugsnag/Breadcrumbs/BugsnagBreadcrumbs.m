//
//  BugsnagBreadcrumbs.m
//  Bugsnag
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//


#import "BugsnagBreadcrumbs.h"

#import "BSGCachesDirectory.h"
#import "BSGJSONSerialization.h"
#import "BugsnagLogger.h"
#import "Private.h"

@interface BugsnagConfiguration ()
@property(nonatomic) NSMutableArray *onBreadcrumbBlocks;
@end

@interface BugsnagBreadcrumb ()
+ (instancetype _Nullable)breadcrumbWithBlock:
    (BSGBreadcrumbConfiguration _Nonnull)block;
+ (instancetype _Nullable)breadcrumbFromDict:(NSDictionary *_Nonnull)dict;
@end

#pragma mark -

@interface BugsnagBreadcrumbs ()

@property BugsnagConfiguration *config;
@property NSArray<BugsnagBreadcrumb *> *breadcrumbs;
@property unsigned int nextFileNumber;
@property unsigned int maxBreadcrumbs;

@end

#pragma mark -

@implementation BugsnagBreadcrumbs

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)config {
    if (!(self = [super init])) {
        return nil;
    }
    
    _config = config;
    _breadcrumbs = [NSArray array];
    // Capture maxBreadcrumbs to protect against config being changed after initialization
    _maxBreadcrumbs = (unsigned int)config.maxBreadcrumbs;
    
    NSError *error = nil;
    NSString *cachesDir = [BSGCachesDirectory cachesDirectory];
    _cachePath = [[cachesDir stringByAppendingPathComponent:@"bugsnag"] stringByAppendingPathComponent:@"breadcrumbs"];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        bsg_log_err(@"Unable to create breadcrumbs directory: %@", error);
    }
    
    _context = calloc(sizeof(BugsnagBreadcrumbsContext), 1);
    _context->directoryPath = strdup(_cachePath.fileSystemRepresentation);
    
    return self;
}

- (void)dealloc {
    free(_context);
}

- (void)addBreadcrumb:(NSString *)breadcrumbMessage {
    [self addBreadcrumbWithBlock:^(BugsnagBreadcrumb *_Nonnull crumb) {
        crumb.message = breadcrumbMessage;
    }];
}

- (void)addBreadcrumbWithBlock:(BSGBreadcrumbConfiguration)block {
    if (self.maxBreadcrumbs == 0) {
        return;
    }
    BugsnagBreadcrumb *crumb = [BugsnagBreadcrumb breadcrumbWithBlock:block];
    if (!crumb || ![self shouldSendBreadcrumb:crumb]) {
        return;
    }
    NSData *data = [self dataForBreadcrumb:crumb];
    if (!data) {
        return;
    }
    unsigned int fileNumber;
    @synchronized (self) {
        NSMutableArray<BugsnagBreadcrumb *> *breadcrumbs = [self.breadcrumbs mutableCopy];
        if (breadcrumbs.count >= self.maxBreadcrumbs) {
            [breadcrumbs removeObjectAtIndex:0];
        }
        [breadcrumbs addObject:crumb];
        self.breadcrumbs = [NSArray arrayWithArray:breadcrumbs];
        fileNumber = self.nextFileNumber;
        self.nextFileNumber = fileNumber + 1;
        if (fileNumber + 1 > self.maxBreadcrumbs) {
            self.context->firstFileNumber = fileNumber + 1 - self.maxBreadcrumbs;
        }
        self.context->nextFileNumber = fileNumber + 1;
    }
    [self writeBreadcrumbData:(NSData *)data toFileNumber:fileNumber];
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

- (void)removeAllBreadcrumbs {
    @synchronized (self) {
        self.breadcrumbs = @[];
        self.nextFileNumber = 0;
        self.context->firstFileNumber = 0;
        self.context->nextFileNumber = 0;
    }
    [self deleteBreadcrumbFiles];
}

#pragma mark - File storage

- (NSData *)dataForBreadcrumb:(BugsnagBreadcrumb *)breadcrumb {
    id JSONObject = [breadcrumb objectValue];
    if (![BSGJSONSerialization isValidJSONObject:JSONObject]) {
        bsg_log_err(@"Unable to serialize breadcrumb: Not a valid JSON object");
        return nil;
    }
    NSError *error = nil;
    NSData *data = [BSGJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
    if (!data) {
        bsg_log_err(@"Unable to serialize breadcrumb: %@", error);
    }
    return data;
}

- (NSString *)pathForFileNumber:(unsigned int)fileNumber {
    return [self.cachePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.json", fileNumber]];
}

- (void)writeBreadcrumbData:(NSData *)data toFileNumber:(unsigned int)fileNumber {
    NSString *path = [self pathForFileNumber:fileNumber];
    
    NSError *error = nil;
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        bsg_log_err(@"Unable to write breadcrumb: %@", error);
        return;
    }
    
    if (fileNumber > self.maxBreadcrumbs) {
        NSString *path = [self pathForFileNumber:fileNumber - self.maxBreadcrumbs];
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
            bsg_log_err(@"Unable to delete old breadcrumb: %@", error);
        }
    }
}

- (nullable NSArray<NSDictionary *> *)cachedBreadcrumbs {
    NSError *error = nil;
    
    NSArray<NSString *> *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_cachePath error:&error];
    if (!filenames) {
        bsg_log_err(@"Unable to read breadcrumbs: %@", error);
        return nil;
    }
    
    NSMutableArray<NSDictionary *> *dictionaries = [NSMutableArray array];
    
    for (NSString *file in [filenames sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *path = [self.cachePath stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) {
            bsg_log_err(@"Unable to read breadcrumb from %@", path);
            continue;
        }
        id JSONObject = [BSGJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!JSONObject) {
            bsg_log_err(@"Unable to parse breadcrumb: %@", error);
            continue;
        }
        if (![JSONObject isKindOfClass:[NSDictionary class]] ||
            ![BugsnagBreadcrumb breadcrumbFromDict:JSONObject]) {
            bsg_log_err(@"Unexpected breadcrumb payload in file %@", file);
            continue;
        }
        [dictionaries addObject:JSONObject];
    }
    
    return dictionaries;
}

- (void)deleteBreadcrumbFiles {
    [[NSFileManager defaultManager] removeItemAtPath:self.cachePath error:NULL];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:self.cachePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        bsg_log_err(@"Unable to create breadcrumbs directory: %@", error);
    }

    NSString *cachesDir = [BSGCachesDirectory cachesDirectory];
    NSString *oldBreadcrumbsPath = [cachesDir stringByAppendingPathComponent:@"bugsnag_breadcrumbs.json"];
    [[NSFileManager defaultManager] removeItemAtPath:oldBreadcrumbsPath error:NULL];
}

@end
