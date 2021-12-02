//
//  BSGSessionUploader.m
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGSessionUploader.h"

#import "BSGFileLocations.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagApiClient.h"
#import "BugsnagCollections.h"
#import "BugsnagConfiguration+Private.h"
#import "BugsnagLogger.h"
#import "BugsnagSession+Private.h"
#import "BugsnagSession.h"
#import "BugsnagSessionFileStore.h"
#import "BugsnagSessionTrackingPayload.h"


@interface BSGSessionUploader ()
@property (nonatomic) NSMutableSet *activeIds;
@property (nonatomic) BugsnagApiClient *apiClient;
@property(nonatomic) BugsnagConfiguration *config;
@property (nonatomic) BugsnagSessionFileStore *fileStore;
@end


@implementation BSGSessionUploader

- (instancetype)initWithConfig:(BugsnagConfiguration *)configuration notifier:(BugsnagNotifier *)notifier {
    if ((self = [super init])) {
        _activeIds = [NSMutableSet new];
        _apiClient = [[BugsnagApiClient alloc] initWithSession:configuration.session queueName:@"Session API queue"];
        _config = configuration;
        _fileStore = [BugsnagSessionFileStore storeWithPath:[BSGFileLocations current].sessions maxPersistedSessions:configuration.maxPersistedSessions];
        _notifier = notifier;
    }
    return self;
}

- (void)uploadSession:(BugsnagSession *)session {
    [self sendSession:session completionHandler:^(BugsnagApiClientDeliveryStatus status) {
        switch (status) {
            case BugsnagApiClientDeliveryStatusDelivered:
                [self uploadStoredSessions];
                break;
                
            case BugsnagApiClientDeliveryStatusFailed:
                [self.fileStore write:session]; // Retry later
                break;
                
            case BugsnagApiClientDeliveryStatusUndeliverable:
                break;
        }
    }];
}

- (void)uploadStoredSessions {
    [[self.fileStore allFilesByName] enumerateKeysAndObjectsUsingBlock:^(NSString *fileId, NSDictionary *fileContents, __unused BOOL *stop) {
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
                [self.fileStore deleteFileWithId:fileId];
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
        [self.apiClient.sendQueue addOperationWithBlock:^{
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
            [self.apiClient sendJSONPayload:data headers:HTTPHeaders toURL:sessionURL
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
