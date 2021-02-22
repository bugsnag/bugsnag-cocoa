//
//  BSGEventUploader.m
//  Bugsnag
//
//  Created by Nick Dowell on 17/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGEventUploader.h"

#import "BSGEventUploadKSCrashReportOperation.h"
#import "BSGEventUploadObjectOperation.h"
#import "BSGFileLocations.h"
#import "BugsnagConfiguration.h"
#import "BugsnagLogger.h"


@interface BSGEventUploader () <BSGEventUploadOperationDelegate>

/// The files currently being uploaded, used to prevent duplicate uploads.
@property (readonly, nonatomic) NSMutableSet<NSString *> *currentFiles;

@property (readonly, nonatomic) NSString *eventsDirectory;

@property (readonly, nonatomic) NSString *kscrashReportsDirectory;

@property (readonly, nonatomic) NSOperationQueue *operationQueue;

@end


// MARK: -

@implementation BSGEventUploader

@synthesize apiClient = _apiClient;
@synthesize configuration = _configuration;
@synthesize notifier = _notifier;

static void *OperationsContext = &OperationsContext;

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)configuration notifier:(BugsnagNotifier *)notifier {
    if (self = [super init]) {
        _apiClient = [[BugsnagApiClient alloc] initWithSession:configuration.session queueName:@""];
        _configuration = configuration;
        _currentFiles = [[NSMutableSet alloc] init];
        _eventsDirectory = [BSGFileLocations current].events;
        _kscrashReportsDirectory = [BSGFileLocations current].kscrashReports;
        _notifier = notifier;
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
        _operationQueue.name = @"com.bugsnag.event-uploader";
        [_operationQueue addObserver:self forKeyPath:NSStringFromSelector(@selector(operations))
                             options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             context:OperationsContext];
    }
    return self;
}

- (void)dealloc {
    [_operationQueue removeObserver:self forKeyPath:NSStringFromSelector(@selector(operations)) context:OperationsContext];
}

// KVO is used to ensure `currentFiles` always reflects the state of the operation queue.
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == OperationsContext) {
        NSMutableArray *addedOperations = [change[NSKeyValueChangeNewKey] mutableCopy];
        [addedOperations removeObjectsInArray:change[NSKeyValueChangeOldKey]];
        
        NSMutableArray *finishedOperations = [change[NSKeyValueChangeOldKey] mutableCopy];
        [finishedOperations removeObjectsInArray:change[NSKeyValueChangeNewKey]];
        
        NSMutableSet<NSString *> *addedFiles = [NSMutableSet set];
        NSMutableSet<NSString *> *finishedFiles = [NSMutableSet set];
        
        for (id operation in addedOperations) {
            if ([operation isKindOfClass:[BSGEventUploadOperation class]]) {
                if ([operation isKindOfClass:[BSGEventUploadFileOperation class]]) {
                    [addedFiles addObject:((BSGEventUploadFileOperation *)operation).file];
                }
            }
        }
        
        for (id operation in finishedOperations) {
            if ([operation isKindOfClass:[BSGEventUploadFileOperation class]]) {
                [finishedFiles addObject:((BSGEventUploadFileOperation *)operation).file];
            }
        }
        
        if (addedFiles.count || finishedFiles.count) {
            @synchronized (self.currentFiles) {
                [self.currentFiles unionSet:addedFiles];
                [self.currentFiles minusSet:finishedFiles];
            }
        }
    }
}

- (void)uploadEvent:(BugsnagEvent *)event {
    [self.operationQueue addOperation:[[BSGEventUploadObjectOperation alloc] initWithEvent:event delegate:self]];
}

- (void)uploadStoredEvents {
    bsg_log_debug(@"Will scan stored events");
    [self.operationQueue addOperationWithBlock:^{
        NSArray<BSGEventUploadFileOperation *> *operations = [self scanStoredEvents];
        bsg_log_debug(@"Uploading %lu stored events", (unsigned long)operations.count);
        [self.operationQueue addOperations:operations waitUntilFinished:NO];
    }];
}

- (void)uploadLatestStoredEvent:(void (^)(void))completionHandler {
    BSGEventUploadFileOperation *operation = [self scanStoredEvents].lastObject;
    if (!operation) {
        bsg_log_warn(@"Could not find a stored event to send");
        completionHandler();
        return;
    }
    operation.completionBlock = completionHandler;
    [self.operationQueue addOperation:operation];
}

/// Scans the events stored on disk, deleting the oldest ones if the count exceeds configuration.maxPersistedEvents,
/// and returns an array of operations (in ascending file creation date ready) to be added to the operation queue.
- (NSArray<BSGEventUploadFileOperation *> *)scanStoredEvents {
    NSMutableArray<BSGEventUploadFileOperation *> *operations = [NSMutableArray array];
    
    NSMutableDictionary<NSString *, NSDate *> *creationDates = [NSMutableDictionary dictionary];
    
    NSArray *currentFiles;
    @synchronized (self.currentFiles) {
        currentFiles = self.currentFiles.allObjects;
    }
    
    for (NSString *directory in @[self.eventsDirectory, self.kscrashReportsDirectory]) {
        NSError *error = nil;
        NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:&error];
        if (!entries) {
            bsg_log_err(@"%@", error);
            continue;
        }
        
        for (NSString *filename in entries) {
            if (![filename.pathExtension isEqual:@"json"] || [filename hasSuffix:@"-CrashState.json"]) {
                continue;
            }
            
            NSString *file = [directory stringByAppendingPathComponent:filename];
            if ([currentFiles containsObject:file]) {
                continue;
            }
            
            if (directory == self.kscrashReportsDirectory) {
                [operations addObject:[[BSGEventUploadKSCrashReportOperation alloc] initWithFile:file delegate:self]];
            } else {
                [operations addObject:[[BSGEventUploadFileOperation alloc] initWithFile:file delegate:self]];
            }
            
            NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil];
            creationDates[file] = attributes.fileCreationDate;
        }
    }
    
    [operations sortUsingComparator:^NSComparisonResult(BSGEventUploadFileOperation *lhs, BSGEventUploadFileOperation *rhs) {
        return [creationDates[lhs.file] compare:creationDates[rhs.file]];
    }];
    
    while (operations.count > self.configuration.maxPersistedEvents) {
        BSGEventUploadFileOperation *operation = operations.firstObject;
        [operations removeObject:operation];
        NSError *error = nil;
        if ([NSFileManager.defaultManager removeItemAtPath:operation.file error:&error]) {
            bsg_log_debug(@"Deleted %@ to meet maxPersistedEvents", operation.name);
        } else {
            bsg_log_err(@"Error while deleting file: %@", error);
        }
    }
    
    return operations;
}

- (void)uploadOperationDidStoreEventPayload:(BSGEventUploadOperation *)uploadOperation {
    [self scanStoredEvents]; // enforces maxPersistedEvents
}

@end
