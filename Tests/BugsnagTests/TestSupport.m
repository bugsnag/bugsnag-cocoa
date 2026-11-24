//
//  TestSupport.m
//  Bugsnag
//
//  Created by Karl Stenerud on 25.09.20.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import "TestSupport.h"

#import "BSG_KSCrashC.h"
#import "BSG_KSCrashState.h"
#import "BSGFileLocations.h"
#import "BSGRunContext.h"
#import "BSGUtils.h"
#import "Bugsnag+Private.h"


@implementation TestSupport

+ (void) purgePersistentData {
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        NSString *dir = [[BSGFileLocations current].events stringByDeletingLastPathComponent];
        // Not every file in the directory is written on this queue (e.g. by clients that earlier tests started), so a
        // file can be created while the directory is being deleted, which then fails because it is not empty. That
        // is a race with work that is still finishing, so the deletion is tried again rather than failing the test.
        // Each attempt waits 100 ms, so this can hold the file system queue for up to 5 s; that only happens when an
        // earlier test left work running, which is what should be fixed in that test.
        // Retries are logged, so that the earlier test that left work running can be found.
        NSError *error = nil;
        int attempt = 0;
        for (; attempt < 50; attempt++) {
            error = nil;
            if ([NSFileManager.defaultManager removeItemAtPath:dir error:&error] ||
                ([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
                error = nil;
                break;
            }
            if (attempt == 0) {
                NSLog(@"TestSupport: could not delete %@, retrying every 100 ms (an earlier test left work running): %@",
                      dir, error);
            }
            [NSThread sleepForTimeInterval:0.1];
        }
        if (attempt > 0 && !error) {
            NSLog(@"TestSupport: deleted %@ after %d retries", dir, attempt);
        }
        if (error) {
            [NSException raise:NSInternalInconsistencyException format:@"Could not delete %@: %@", dir, error];
        }
    });
    
    [Bugsnag purge];
    
    bsg_lastRunContext = NULL;
}

@end
