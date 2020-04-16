//
// Created by Jamie Lynch on 30/11/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingApiClient.h"
#import "BugsnagConfiguration.h"
#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagSessionFileStore.h"
#import "BugsnagLogger.h"
#import "BugsnagSession.h"
#import "BugsnagSessionInternal.h"
#import "BSG_RFC3339DateTool.h"
#import "Private.h"

@interface BugsnagConfiguration ()
@property(nonatomic, readwrite, strong) NSMutableArray *onSessionBlocks;
@property(readonly, retain, nullable) NSURL *sessionURL;
@end


@implementation BugsnagSessionTrackingApiClient

- (NSOperation *)deliveryOperation {
    return [NSOperation new];
}

- (void)deliverSessionsInStore:(BugsnagSessionFileStore *)store {
    NSString *apiKey = [self.config.apiKey copy];
    NSURL *sessionURL = [self.config.sessionURL copy];

    if (!apiKey) {
        bsg_log_err(@"No API key set. Refusing to send sessions.");
        return;
    }

    NSDictionary<NSString *, NSDictionary *> *filesWithIds = [store allFilesByName];

    if (filesWithIds.count <= 0) {
        return;
    }

    for (NSString *fileId in [filesWithIds allKeys]) {
        BugsnagSession *session = [[BugsnagSession alloc] initWithDictionary:filesWithIds[fileId]];

        [self.sendQueue addOperationWithBlock:^{
            BugsnagSessionTrackingPayload *payload = [[BugsnagSessionTrackingPayload alloc] initWithSessions:@[session] config:[Bugsnag configuration]];
            NSUInteger sessionCount = payload.sessions.count;
            NSMutableDictionary *data = [payload toJson];

            if (sessionCount > 0) {
                NSDictionary *HTTPHeaders = @{
                        @"Bugsnag-Payload-Version": @"1.0",
                        @"Bugsnag-API-Key": apiKey,
                        @"Bugsnag-Sent-At": [BSG_RFC3339DateTool stringFromDate:[NSDate new]]
                };
                [self sendItems:1
                    withPayload:data
                          toURL:sessionURL
                        headers:HTTPHeaders
                   onCompletion:^(NSUInteger sentCount, BOOL success, NSError *error) {
                       if (success && error == nil) {
                           bsg_log_info(@"Sent %lu sessions to Bugsnag", (unsigned long) sessionCount);
                           [store deleteFileWithId:fileId];
                       } else {
                           bsg_log_warn(@"Failed to send sessions to Bugsnag: %@", error);
                       }
                   }];
            }
        }];
    }
}

@end
