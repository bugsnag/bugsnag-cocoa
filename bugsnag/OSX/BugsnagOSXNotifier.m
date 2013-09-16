//
//  BugsnagOSXNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 9/12/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagOSXNotifier.h"

@interface BugsnagOSXNotifier ()
@property (readonly) NSString* topMostWindowTitle;
@property (readonly) NSString* topMostDocumentDisplayName;
- (void) addOSXDiagnosticsToEvent:(BugsnagEvent*) event;
@end

@implementation BugsnagOSXNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        self.notifierName = @"OSX Bugsnag Notifier";
        
        [self beforeNotify:^(BugsnagEvent *event) {
            [self addOSXDiagnosticsToEvent:event];
            return YES;
        }];
    }
    return self;
}

- (void) addOSXDiagnosticsToEvent:(BugsnagEvent*) event {
    NSString *topMostWindowTitle = self.topMostWindowTitle;
    if (topMostWindowTitle != nil) {
        if (event.context == nil) event.context = topMostWindowTitle;

        [event addAttribute:@"Top Most Window" withValue:topMostWindowTitle toTabWithName:@"application"];
    }
    
    NSString *topMostDocumentDisplayName = self.topMostDocumentDisplayName;
    if (topMostDocumentDisplayName != nil) [event addAttribute:@"Top Most Document" withValue:topMostDocumentDisplayName toTabWithName:@"application"];
    
    [event addAttribute:@"Active" withValue:[NSNumber numberWithBool:[[NSApplication sharedApplication] isActive]] toTabWithName:@"application"];
}

- (NSString *) topMostWindowTitle {
    NSArray *windows = [[NSApplication sharedApplication] orderedWindows];
    if (windows.count > 0) {
        return ((NSWindow*)[windows objectAtIndex:0]).title;
    } else {
        return nil;
    }
}

- (NSString *) topMostDocumentDisplayName {
    NSArray *documents = [[NSApplication sharedApplication] orderedDocuments];
    if (documents.count > 0) {
        return ((NSDocument*)[documents objectAtIndex:0]).displayName;
    } else {
        return nil;
    }
}

@end
