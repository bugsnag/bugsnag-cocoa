//
//  BSGSessionUploader.h
//  Bugsnag
//
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class BugsnagNotifier;
@class BugsnagSession;

NS_ASSUME_NONNULL_BEGIN

@interface BSGSessionUploader : NSObject

- (instancetype)initWithConfig:(BugsnagConfiguration *)configuration notifier:(BugsnagNotifier *)notifier;

/// Scans previously persisted sessions and either discards or attempts upload.
- (void)processStoredSessions;

- (void)uploadSession:(BugsnagSession *)session;

@property (copy, nonatomic) NSString *codeBundleId;

@property (nonatomic) BugsnagNotifier *notifier;

@end

NS_ASSUME_NONNULL_END
