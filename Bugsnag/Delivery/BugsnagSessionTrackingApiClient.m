//
// Created by Jamie Lynch on 30/11/2017.
// Copyright (c) 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingApiClient.h"

#import "BSGFileLocations.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagCollections.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagLogger.h"
#import "BugsnagSession+Private.h"
#import "BugsnagSession.h"
#import "BugsnagSessionFileStore.h"
#import "BugsnagSessionTrackingPayload.h"


@interface BugsnagSessionTrackingApiClient ()
@property (nonatomic) NSMutableSet *activeIds;
@property(nonatomic) BugsnagConfiguration *config;
@property (nonatomic) BugsnagSessionFileStore *fileStore;
@end


@implementation BugsnagSessionTrackingApiClient

- (instancetype)initWithConfig:(BugsnagConfiguration *)configuration queueName:(NSString *)queueName notifier:(BugsnagNotifier *)notifier {
    if ((self = [super initWithSession:configuration.session queueName:queueName])) {
        _activeIds = [NSMutableSet new];
        _config = configuration;
        _fileStore = [BugsnagSessionFileStore storeWithPath:[BSGFileLocations current].sessions maxPersistedSessions:configuration.maxPersistedSessions];
        _notifier = notifier;
    }
    return self;
}

- (NSOperation *)deliveryOperation {
    return [NSOperation new];
}

- (void)deliverSession:(BugsnagSession *)session {
    [self sendSession:session completionHandler:^(BugsnagApiClientDeliveryStatus status) {
        switch (status) {
            case BugsnagApiClientDeliveryStatusDelivered:
                [self deliverSessionsInStore:self.fileStore];
                break;
                
            case BugsnagApiClientDeliveryStatusFailed:
                [self.fileStore write:session]; // Retry later
                break;
                
            case BugsnagApiClientDeliveryStatusUndeliverable:
                break;
        }
    }];
}

- (void)deliverSessionsInStore:(BugsnagSessionFileStore *)store {
    [[store allFilesByName] enumerateKeysAndObjectsUsingBlock:^(NSString *fileId, NSDictionary *fileContents, __attribute__((unused)) BOOL *stop) {
        // De-duplicate files as deletion of the file is asynchronous and so multiple calls
        // to this method will result in multiple send requests
        @synchronized (self.activeIds) {
            if ([self.activeIds containsObject:fileId]) {
                return;
            }
            [self.activeIds addObject:fileId];
        }

        BugsnagSession *session = [[BugsnagSession alloc] initWithDictionary:fileContents];

        [self sendSession:session completionHandler:^(BugsnagApiClientDeliveryStatus status) {
            if (status != BugsnagApiClientDeliveryStatusFailed) {
                [store deleteFileWithId:fileId];
            }
            @synchronized (self.activeIds) {
                [self.activeIds removeObject:fileId];
            }
        }];
    }];
}

- (void)sendSession:(BugsnagSession *)session completionHandler:(void (^)(BugsnagApiClientDeliveryStatus status))completionHandler {
    NSString *apiKey = [self.config.apiKey copy];
    NSURL *sessionURL = [self.config.sessionURL copy];
    
    if (!apiKey) {
        bsg_log_err(@"Cannot send session because no apiKey is configured.");
        completionHandler(BugsnagApiClientDeliveryStatusUndeliverable);
        return;
    }
    
    if (sessionURL) {
        [self.sendQueue addOperationWithBlock:^{
            BugsnagSessionTrackingPayload *payload = [[BugsnagSessionTrackingPayload alloc]
                initWithSessions:@[session]
                          config:self.config
                    codeBundleId:self.codeBundleId
                        notifier:self.notifier];
            NSMutableDictionary *data = [payload toJson];
            NSDictionary *HTTPHeaders = @{
                BugsnagHTTPHeaderNameApiKey: apiKey ?: @"",
                BugsnagHTTPHeaderNamePayloadVersion: @"1.0",
                BugsnagHTTPHeaderNameSentAt: [BSG_RFC3339DateTool stringFromDate:[NSDate date]]
            };
            [self sendJSONPayload:data headers:HTTPHeaders toURL:sessionURL
                completionHandler:^(BugsnagApiClientDeliveryStatus status, NSError *error) {
                switch (status) {
                    case BugsnagApiClientDeliveryStatusDelivered:
                        bsg_log_info(@"Sent session %@", session.id);
                        break;
                    case BugsnagApiClientDeliveryStatusFailed:
                        bsg_log_warn(@"Failed to send sessions: %@", error);
                        break;
                    case BugsnagApiClientDeliveryStatusUndeliverable:
                        bsg_log_warn(@"Failed to send sessions: %@", error);
                        break;
                }
                completionHandler(status);
            }];
        }];
    } else {
        bsg_log_err(@"Cannot send session because no endpoint is configured.");
        completionHandler(BugsnagApiClientDeliveryStatusUndeliverable);
    }
}

@end
