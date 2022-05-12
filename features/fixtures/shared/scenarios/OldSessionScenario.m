//
//  OldSessionScenario.m
//  macOSTestApp
//
//  Created by Nick Dowell on 11/05/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#import "Scenario.h"

@interface OldSessionScenario : Scenario
@end

@implementation OldSessionScenario

- (void)startBugsnag {
    if ([self.eventMode isEqualToString:@"new"]) {
        [self modifySessionCreationDate];
    }
    [self.config setUser:self.eventMode withEmail:nil andName:nil];
    [super startBugsnag];
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
        NSLog(@"OldSessionScenario: Updated creation date of %@ to %@", file.lastPathComponent,
              [NSFileManager.defaultManager attributesOfItemAtPath:file error:nil].fileCreationDate);
    } else {
        NSLog(@"OldSessionScenario: %@", error);
        abort();
    }
}

@end
