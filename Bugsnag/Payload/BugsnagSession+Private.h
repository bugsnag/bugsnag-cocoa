//
//  BugsnagSession+Private.h
//  Bugsnag
//
//  Created by Nick Dowell on 23/11/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <Bugsnag/BugsnagSession.h>

NS_ASSUME_NONNULL_BEGIN

@class BugsnagUser;

@interface BugsnagSession () <NSCopying>

#pragma mark Initializers

- (instancetype)initWithId:(NSString *)sessionId
                 startedAt:(NSDate *)startedAt
                      user:(BugsnagUser *)user
                       app:(BugsnagApp *)app
                    device:(BugsnagDevice *)device;

#pragma mark Properties

@property (nonatomic) NSUInteger handledCount;

@property (getter=isStopped, nonatomic) BOOL stopped;

@property (nonatomic) NSUInteger unhandledCount;

@property (readwrite, nonnull, nonatomic) BugsnagUser *user;

@end

#pragma mark Serialization

/// Produces a session dictionary that contains all the information to fully recreate it via BSGSessionFromDictionary().
NSDictionary * BSGSessionToDictionary(BugsnagSession *session);

/// Parses a session dictionary produced by BSGSessionToDictionary() or added to a KSCrashReport by BSSerializeDataCrashHandler().
BugsnagSession *_Nullable BSGSessionFromDictionary(NSDictionary *_Nullable json);

/// Produces a session dictionary suitable for inclusion in an event's JSON representation.
NSDictionary * BSGSessionToEventJson(BugsnagSession *session);

/// Parses a session dictionary from an event's JSON representation.
BugsnagSession *_Nullable BSGSessionFromEventJson(NSDictionary *_Nullable json, BugsnagApp *app, BugsnagDevice *device, BugsnagUser *user);

NS_ASSUME_NONNULL_END
