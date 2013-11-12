//
//  BugsnagOSXNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 9/12/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import "BugsnagOSXNotifier.h"

#import <ExceptionHandling/NSExceptionHandler.h>

@interface BugsnagOSXNotifier ()
@end

@implementation BugsnagOSXNotifier

- (id) initWithConfiguration:(BugsnagConfiguration*) configuration {
    if((self = [super initWithConfiguration:configuration])) {
        self.notifierName = @"OSX Bugsnag Notifier";
        
        [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:NSLogAndHandleEveryExceptionMask];
        [[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
    }
    return self;
}

- (BugsnagDictionary *) collectAppState {

    BugsnagDictionary *appState = [super collectAppState];

    NSArray *documents = [[NSApplication sharedApplication] orderedDocuments];
    NSArray *windows = [[NSApplication sharedApplication] orderedWindows];

    NSMutableArray *documentNames = [NSMutableArray arrayWithCapacity: documents.count];
    NSMutableArray *windowTitles = [NSMutableArray arrayWithCapacity: windows.count];

    for (int i = 0; i < windows.count; i++) {
        [windowTitles insertObject: ((NSWindow*)[windows objectAtIndex: i]).title atIndex: i];
    }
    for (int i = 0; i < documents.count; i++) {
        [documentNames insertObject:((NSDocument*)[documents objectAtIndex: i]).displayName atIndex: i];
    }
    
    if (windowTitles.count > 0) {
        [appState setObject: [windowTitles objectAtIndex:0] forKey:@"activeScreen"];
        [appState setObject: windowTitles forKey:@"orderedWindows"];
    }
    
    if (documentNames.count > 0) {
        [appState setObject: documentNames forKey:@"orderedDocuments"];
    }

    return appState;
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(NSUInteger)aMask {
    [self notifyException:exception withData:nil atSeverity:@"fatal" inBackground:YES];
    return NO;
}

@end
