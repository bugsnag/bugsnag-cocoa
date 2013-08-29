//
//  BugsnagNotifier.m
//  Bugsnag
//
//  Created by Simon Maynard on 8/28/13.
//  Copyright (c) 2013 Simon Maynard. All rights reserved.
//

#import <execinfo.h>

#import "BugsnagNotifier.h"
#import "BugsnagLogger.h"
#import "BugsnagJSON.h"

@interface BugsnagNotifier () {
    NSString *_errorPath;
}
@property (atomic, strong) NSMutableArray *beforeBugsnagNotifyBlocks;
@end

@implementation BugsnagNotifier

- (id) init {
    if((self = [super init])) {
        self.configuration = [[BugsnagConfiguration alloc] init];
        self.beforeBugsnagNotifyBlocks = [NSMutableArray array];
        
        self.notifierName = @"Bugsnag Objective-C";
        //TODO:SM Pull this out from somewhere in cocoapods if poss
        self.notifierVersion = @"3.0.0";
        self.notifierURL = @"https://github.com/bugsnag/bugsnag-objective-c";
    }
    return self;
}

- (void) notifySignal:(int)signal {
    if([self shouldAutoNotify]) {
        BugsnagEvent *event = [[BugsnagEvent alloc] initWithConfiguration:self.configuration andMetaData:nil];
        [event addSignal:signal];
        
        [self saveEvent:event];
        [self sendSavedEvents];
    }
}

- (void) notifyUncaughtException:(NSException *)exception {
    if ([self shouldAutoNotify]) {
        [self notifyException:exception withData:nil];
    }
}

- (void) notifyException:(NSException*)exception withData:(NSDictionary*)metaData {
    if ([self shouldNotify]) {
        BugsnagEvent *event = [[BugsnagEvent alloc] initWithConfiguration:self.configuration andMetaData:nil];
        [event addException:exception];
        
        [self saveEvent:event];
        [self sendSavedEvents];
    }
}

- (BOOL) shouldNotify {
    return self.configuration.notifyReleaseStages == nil || [self.configuration.notifyReleaseStages containsObject:self.configuration.releaseStage];
}

- (BOOL) shouldAutoNotify {
    return self.configuration.autoNotify && [self shouldNotify];
}

- (NSDictionary*) buildNotifyPayload {
    NSDictionary *notifierDetails = [NSDictionary dictionaryWithObjectsAndKeys:self.notifierName, @"name",
                                                                               self.notifierVersion, @"version",
                                                                               self.notifierURL, @"url", nil];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:notifierDetails, @"notifier",
                                                                       self.configuration.apiKey, @"apiKey",
                                                                       [NSMutableArray array], @"events", nil];
    
    return payload;
}

- (void) beforeNotify:(BugsnagNotifyBlock)block {
    [self.beforeBugsnagNotifyBlocks addObject:block];
}

- (void) saveEvent:(BugsnagEvent*)event {
    [[NSFileManager defaultManager] createDirectoryAtPath:self.errorPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSDictionary *eventDictionary = [event toDictionary];
    
    if(![eventDictionary writeToFile:[self generateEventFilename] atomically:YES]) {
        BugsnagLog(@"BUGSNAG: Unable to write event file!");
    }
}

- (NSArray *) savedEvents {
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.errorPath error:nil];
	NSMutableArray *savedReports = [NSMutableArray arrayWithCapacity:[directoryContents count]];
	for (NSString *file in directoryContents) {
		if ([[file pathExtension] isEqualToString:@"bugsnag"]) {
			NSString *crashPath = [self.errorPath stringByAppendingPathComponent:file];
			[savedReports addObject:crashPath];
		}
	}
	return savedReports;
}

- (void) sendSavedEvents {
    @synchronized(self) {
        @try {
            NSArray *savedEvents = [self savedEvents];
            for ( NSString *file in savedEvents ) {
                NSMutableDictionary *event = [NSMutableDictionary dictionaryWithContentsOfFile:file];
                if (event == nil || [self sendEvent:event]) {
                    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
                }
            }
        }
        @catch (NSException *exception) {
            BugsnagLog(@"Exception while sending bugsnag events: %@", exception);
        }
    }
}

- (BOOL) sendEvent:(NSDictionary*)event {
    if (event == nil) {
        return NO;
    }
    
    NSDictionary *notifyPayload = [self buildNotifyPayload];
    NSMutableArray *events = [notifyPayload objectForKey:@"events"];
    [events addObject:event];
    NSString *jsonPayload = [BugsnagJSON encodeDictionary:notifyPayload];
    if(jsonPayload){
        // TODO:SM Remove this
        NSLog(@"Would send: %@", jsonPayload);
        return YES;
        NSMutableURLRequest *request = nil;
        if(self.configuration.enableSSL) {
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://notify.bugsnag.com"]];
        } else {
            request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://notify.bugsnag.com"]];
        }
        
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[jsonPayload dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        
        NSURLResponse* response = nil;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
        
        int statusCode = [((NSHTTPURLResponse *)response) statusCode];
        if (statusCode != 200) {
            BugsnagLog(@"Bad response from bugsnag received: %d.", statusCode);
        } else {
            return YES;
        }
    }
    return NO;
}

- (NSString*) errorPath {
    if(_errorPath) return _errorPath;
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *filename = [folders count] == 0 ? NSTemporaryDirectory() : [folders objectAtIndex:0];
    _errorPath = [filename stringByAppendingPathComponent:@"bugsnag"];
    return _errorPath;
}

- (NSString *) generateEventFilename {
    return [[self.errorPath stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] stringByAppendingPathExtension:@"bugsnag"];
}

@end
