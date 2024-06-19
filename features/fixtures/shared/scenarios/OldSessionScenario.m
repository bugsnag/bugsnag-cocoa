//
//  OldSessionScenario.m
//  macOSTestApp
//
//  Created by Nick Dowell on 11/05/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

@interface OldSessionScenario : Scenario
@end

@implementation OldSessionScenario

- (void)configure {
    [super configure];
    if ([self.args[0] isEqualToString:@"new"]) {
        [self modifySessionCreationDate];
    }
    [self.config setUser:self.args[0] withEmail:nil andName:nil];
}

- (void)run {
}

- (void)modifySessionCreationDate {
    NSString *dir = [@[
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0],
        @"com.bugsnag.Bugsnag",
        NSBundle.mainBundle.bundleIdentifier,
        @"v1",
        @"sessions"
    ] componentsJoinedByString:@"/"];
    
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *creationDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-61 toDate:[NSDate date] options:0];
    
    NSString *name = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil][0];
    NSString *file = [dir stringByAppendingPathComponent:name];
    NSError *error;
    if ([NSFileManager.defaultManager setAttributes:@{NSFileCreationDate: creationDate} ofItemAtPath:file error:&error]) {
        logDebug(@"OldSessionScenario: Updated creation date of %@ to %@", file.lastPathComponent,
              [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil].fileCreationDate);
    } else {
        logError(@"OldSessionScenario: %@", error);
        abort();
    }
}

@end
