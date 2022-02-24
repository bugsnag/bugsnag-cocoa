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
#import "BSGUtils.h"
#import "Bugsnag+Private.h"


@implementation TestSupport

+ (void) purgePersistentData {
    dispatch_sync(BSGGetFileSystemQueue(), ^{
        NSString *dir = [[BSGFileLocations current].events stringByDeletingLastPathComponent];
        NSError *error = nil;
        if (![NSFileManager.defaultManager removeItemAtPath:dir error:&error] &&
            !([error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFileNoSuchFileError)) {
            [NSException raise:NSInternalInconsistencyException format:@"Could not delete %@", dir];
        }
    });
    
    [Bugsnag purge];
    
    // bsg_kscrash_install() will refuse to install itself twice, so reinit kscrashstate to avoid leaking state between tests
    NSString *path = [BSGFileLocations current].state;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    bsg_kscrashstate_init(path.fileSystemRepresentation, &crashContext()->state);
}

@end
