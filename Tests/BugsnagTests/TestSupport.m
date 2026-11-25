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
        // Work left running by earlier tests can write files off this queue, making the delete fail as not empty.
        // Retry every 100 ms (up to 5 s on this queue) and log, so the offending test can be found and fixed.
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
