//
//  BugsnagBreadcrumbs.m
//  Bugsnag
//
//  Created by Jamie Lynch on 26/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagBreadcrumbs.h"

#import "BSGFileLocations.h"
#import "BSGJSONSerialization.h"
#import "BSGUtils.h"
#import "BSG_KSCrashReportWriter.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagBreadcrumb+Private.h"
#import "BugsnagCollections.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagLogger.h"

#import <sqlite3.h>
#import <stdatomic.h>

//
// Breadcrumbs are stored as a linked list of JSON encoded C strings
// so that they are accessible at crash time.
//

struct bsg_breadcrumb_list_item {
    struct bsg_breadcrumb_list_item *next;
    char jsonData[]; // MUST be null terminated
};

static _Atomic(struct bsg_breadcrumb_list_item *) g_breadcrumbs_head;
static atomic_bool g_writing_crash_report;

#pragma mark -

@interface BugsnagBreadcrumbs ()

@property (nonatomic) BugsnagConfiguration *config;
@property (nonatomic) unsigned int nextFileNumber;
@property (nonatomic) unsigned int maxBreadcrumbs;

@property (nonatomic) sqlite3 *sqlite;
@property (nonatomic) sqlite3_stmt *insert;
@property (nonatomic) sqlite3_stmt *trim;

@end

#pragma mark -

BSG_OBJC_DIRECT_MEMBERS
@implementation BugsnagBreadcrumbs

- (instancetype)initWithConfiguration:(BugsnagConfiguration *)config {
    if (!(self = [super init])) {
        return nil;
    }
    
    _config = config;
    // Capture maxBreadcrumbs to protect against config being changed after initialization
    _maxBreadcrumbs = (unsigned int)config.maxBreadcrumbs;
    
    NSString *path = [[BSGFileLocations current].breadcrumbs
                      stringByAppendingPathExtension:@"sqlite"];
    
    if (sqlite3_open(path.fileSystemRepresentation, &_sqlite) != SQLITE_OK) {
        sqlite3_close(_sqlite);
        _sqlite = NULL;
    } else {
        int status;
        
        status = sqlite3_exec(_sqlite, "PRAGMA journal_mode=WAL", NULL, NULL, NULL);
        NSParameterAssert(status == SQLITE_OK);
        
        status = sqlite3_exec(_sqlite,
                              "CREATE TABLE IF NOT EXISTS Breadcrumbs ("
                              " id INTEGER UNIQUE PRIMARY KEY AUTOINCREMENT,"
                              " value BLOB"
                              ")",
                              NULL, NULL, NULL);
        NSParameterAssert(status == SQLITE_OK);
        
        status = sqlite3_prepare_v2(_sqlite,
                                    "INSERT INTO Breadcrumbs (value) VALUES (?)",
                                    -1,
                                    &_insert,
                                    NULL);
        NSParameterAssert(status == SQLITE_OK);
        NSParameterAssert(_insert != NULL);
        
        status = sqlite3_prepare_v2(_sqlite,
                                    "DELETE FROM Breadcrumbs "
                                    "WHERE id NOT IN ("
                                    " SELECT id FROM Breadcrumbs ORDER BY id DESC LIMIT ?"
                                    ")",
                                    -1,
                                    &_trim,
                                    NULL);
        NSParameterAssert(status == SQLITE_OK);
        NSParameterAssert(_trim != NULL);
        
        status = sqlite3_bind_int(_trim, 1, (int)self.maxBreadcrumbs);
        NSParameterAssert(status == SQLITE_OK);
    }
    
    return self;
}

- (NSArray<BugsnagBreadcrumb *> *)breadcrumbs {
    NSMutableArray<BugsnagBreadcrumb *> *breadcrumbs = [NSMutableArray array];
    @synchronized (self) {
        for (struct bsg_breadcrumb_list_item *item = atomic_load(&g_breadcrumbs_head); item != NULL; item = item->next) {
            NSError *error = nil;
            NSData *data = [NSData dataWithBytesNoCopy:item->jsonData length:strlen(item->jsonData) freeWhenDone:NO];
            NSDictionary *JSONObject = BSGJSONDictionaryFromData(data, 0, &error);
            if (!JSONObject) {
                bsg_log_err(@"Unable to parse breadcrumb: %@", error);
                continue;
            }
            BugsnagBreadcrumb *breadcrumb = [BugsnagBreadcrumb breadcrumbFromDict:JSONObject];
            if (!breadcrumb) {
                bsg_log_err(@"Unexpected breadcrumb payload in buffer");
                continue;
            }
            [breadcrumbs addObject:breadcrumb];
        }
    }
    return breadcrumbs;
}

- (NSArray<BugsnagBreadcrumb *> *)breadcrumbsBeforeDate:(nonnull NSDate *)date {
    // Because breadcrumbs are stored with only millisecond accuracy, we must also round the beforeDate in the same way.
    NSString *dateString = [BSG_RFC3339DateTool stringFromDate:date];
    return BSGArrayMap(self.breadcrumbs, ^id _Nullable(BugsnagBreadcrumb *crumb) {
        // Using `timestampString` is more efficient because `timestamp` is a computed by parsing `timestampString`.
        if ([crumb.timestampString compare:dateString] == NSOrderedDescending) {
            return nil;
        }
        return crumb;
    });
}

- (void)addBreadcrumb:(BugsnagBreadcrumb *)crumb {
    if (self.maxBreadcrumbs == 0) {
        return;
    }
    if (![crumb isValid] || ![self shouldSendBreadcrumb:crumb]) {
        return;
    }
    NSData *data = [self dataForBreadcrumb:crumb];
    if (!data) {
        return;
    }
    [self addBreadcrumbWithData:data writeToDisk:YES];
}

- (void)addBreadcrumbWithData:(NSData *)data writeToDisk:(BOOL)writeToDisk {
    struct bsg_breadcrumb_list_item *newItem = calloc(1, sizeof(struct bsg_breadcrumb_list_item) + data.length + 1);
    if (!newItem) {
        return;
    }
    [data getBytes:newItem->jsonData length:data.length];
    
    @synchronized (self) {
        const unsigned int fileNumber = self.nextFileNumber;
        const BOOL deleteOld = fileNumber >= self.maxBreadcrumbs;
        self.nextFileNumber = fileNumber + 1;
        
        struct bsg_breadcrumb_list_item *head = atomic_load(&g_breadcrumbs_head);
        if (head) {
            struct bsg_breadcrumb_list_item *tail = head;
            while (tail->next) {
                tail = tail->next;
            }
            tail->next = newItem;
            if (deleteOld) {
                atomic_store(&g_breadcrumbs_head, head->next);
                while (atomic_load(&g_writing_crash_report)) { continue; }
                free(head);
            }
        } else {
            atomic_store(&g_breadcrumbs_head, newItem);
        }
        
        if (!writeToDisk) {
            return;
        }
        //
        // Breadcrumbs are also stored on disk so that they are accessible at next
        // launch if an OOM is detected.
        //
        dispatch_async(BSGGetFileSystemQueue(), ^{
            [self insertBreadcrumbWithData:data];
            [self trimBreadcrumbs];
        });
    }
}

#define CHECK_EQUALS(expr, eres) ({ \
    int result = (expr); \
    if (result != eres) { \
        bsg_log_err("%s in " #expr, sqlite3_errstr(result)); \
    } \
})

- (void)insertBreadcrumbWithData:(NSData *)data {
    sqlite3_stmt *insert = self.insert;
    CHECK_EQUALS(sqlite3_bind_blob(insert, 1, data.bytes, (int)data.length, SQLITE_STATIC), SQLITE_OK);
    CHECK_EQUALS(sqlite3_step(insert), SQLITE_DONE);
    CHECK_EQUALS(sqlite3_clear_bindings(insert), SQLITE_OK);
    CHECK_EQUALS(sqlite3_reset(insert), SQLITE_OK);
}

- (void)trimBreadcrumbs {
    sqlite3_stmt *trim = self.trim;
    CHECK_EQUALS(sqlite3_step(trim), SQLITE_DONE);
    CHECK_EQUALS(sqlite3_reset(trim), SQLITE_OK);
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
        struct bsg_breadcrumb_list_item *item = atomic_exchange(&g_breadcrumbs_head, NULL);
        while (item) {
            struct bsg_breadcrumb_list_item *next = item->next;
            free(item);
            item = next;
        }
        self.nextFileNumber = 0;
    }
    dispatch_async(BSGGetFileSystemQueue(), ^{
        sqlite3_exec(self.sqlite, "DELETE FROM Breadcrumbs", NULL, NULL, NULL);
    });
}

#pragma mark - File storage

- (NSData *)dataForBreadcrumb:(BugsnagBreadcrumb *)breadcrumb {
    NSData *data = nil;
    NSError *error = nil;
    NSDictionary *json = [breadcrumb objectValue];
    if (!json || !(data = BSGJSONDataFromDictionary(json, &error))) {
        bsg_log_err(@"Unable to serialize breadcrumb: %@", error);
    }
    return data;
}

- (NSArray<BugsnagBreadcrumb *> *)cachedBreadcrumbs {
    sqlite3_stmt *select = NULL;
    
    int status;
    status = sqlite3_prepare_v2(self.sqlite,
                                "SELECT value from Breadcrumbs",
                                -1, &select, NULL);
    NSParameterAssert(status == SQLITE_OK);
    
    NSMutableArray *breadcrumbs = [NSMutableArray array];
    
    for (;;) {
        status = sqlite3_step(select);
        if (status != SQLITE_ROW) {
            break;
        } 
        const void *blob = sqlite3_column_blob(select, 0);
        int length = sqlite3_column_bytes(select, 0);
        if (!blob || !length) {
            continue;
        }
        NSError *error = nil;
        NSData *data = [NSData dataWithBytes:blob length:(NSUInteger)length];
        NSDictionary *JSONObject = BSGJSONDictionaryFromData(data, 0, &error);
        if (!JSONObject) {
            bsg_log_err(@"Unable to parse breadcrumb: %@", error);
            continue;
        }
        BugsnagBreadcrumb *breadcrumb = [BugsnagBreadcrumb breadcrumbFromDict:JSONObject];
        if (!breadcrumb) {
            bsg_log_err(@"Unexpected breadcrumb payload");
            continue;
        }
        [breadcrumbs addObject:breadcrumb];
    }
    
    status = sqlite3_reset(select);
    NSParameterAssert(status == SQLITE_OK);
    
    status = sqlite3_finalize(select);
    NSParameterAssert(status == SQLITE_OK);
    
    return breadcrumbs;
}

@end

#pragma mark -

void BugsnagBreadcrumbsWriteCrashReport(const BSG_KSCrashReportWriter *writer) {
    atomic_store(&g_writing_crash_report, true);
    
    writer->beginArray(writer, "breadcrumbs");
    
    struct bsg_breadcrumb_list_item *item = atomic_load(&g_breadcrumbs_head);
    while (item) {
        writer->addJSONElement(writer, NULL, item->jsonData);
        item = item->next;
    }
    
    writer->endContainer(writer);
    
    atomic_store(&g_writing_crash_report, false);
}
