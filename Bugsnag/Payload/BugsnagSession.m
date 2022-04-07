//
//  BugsnagSession.m
//  Bugsnag
//
//  Created by Jamie Lynch on 24/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSession+Private.h"

#import "BSGKeys.h"
#import "BSG_RFC3339DateTool.h"
#import "BugsnagApp+Private.h"
#import "BugsnagDevice+Private.h"
#import "BugsnagUser+Private.h"

@implementation BugsnagSession

- (instancetype)initWithId:(NSString *)sessionId
                 startedAt:(NSDate *)startedAt
                      user:(BugsnagUser *)user
                       app:(BugsnagApp *)app
                    device:(BugsnagDevice *)device {
    if ((self = [super init])) {
        _id = [sessionId copy];
        _startedAt = startedAt;
        _user = user;
        _app = app;
        _device = device;
    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    BugsnagSession *session = [[[self class] allocWithZone:zone]
                               initWithId:self.id
                               startedAt:self.startedAt
                               user:self.user
                               app:self.app
                               device:self.device];
    session.handledCount = self.handledCount;
    session.unhandledCount = self.unhandledCount;
    return session;
}

- (void)setUser:(NSString *_Nullable)userId
      withEmail:(NSString *_Nullable)email
        andName:(NSString *_Nullable)name {
    self.user = [[BugsnagUser alloc] initWithUserId:userId name:name emailAddress:email];
}

@end

#pragma mark -

NSDictionary * BSGSessionToDictionary(BugsnagSession *session) {
    return @{
        BSGKeyApp: [session.app toDict] ?: @{},
        BSGKeyDevice: [session.device toDictionary] ?: @{},
        BSGKeyHandledCount: @(session.handledCount),
        BSGKeyId: session.id,
        BSGKeyStartedAt: [BSG_RFC3339DateTool stringFromDate:session.startedAt] ?: [NSNull null],
        BSGKeyUnhandledCount: @(session.unhandledCount),
        BSGKeyUser: [session.user toJson] ?: @{}
    };
}

BugsnagSession *_Nullable BSGSessionFromDictionary(NSDictionary *json) {
    NSString *sessionId = json[BSGKeyId];
    NSDate *startedAt = [BSG_RFC3339DateTool dateFromString:json[BSGKeyStartedAt]];
    if (!sessionId || !startedAt) {
        return nil;
    }
    BugsnagApp *app = [BugsnagApp deserializeFromJson:json[BSGKeyApp]];
    BugsnagDevice *device = [BugsnagDevice deserializeFromJson:json[BSGKeyDevice]];
    BugsnagUser *user = [[BugsnagUser alloc] initWithDictionary:json[BSGKeyUser]];
    BugsnagSession *session = [[BugsnagSession alloc] initWithId:sessionId startedAt:startedAt user:user app:app device:device];
    session.handledCount = [json[BSGKeyHandledCount] unsignedIntegerValue];
    session.unhandledCount = [json[BSGKeyUnhandledCount] unsignedIntegerValue];
    return session;
}

NSDictionary * BSGSessionToEventJson(BugsnagSession *session) {
    return @{
        BSGKeyEvents: @{
            BSGKeyHandled: @(session.handledCount),
            BSGKeyUnhandled: @(session.unhandledCount)
        },
        BSGKeyId: session.id,
        BSGKeyStartedAt: [BSG_RFC3339DateTool stringFromDate:session.startedAt] ?: [NSNull null]
    };
}

BugsnagSession * BSGSessionFromEventJson(NSDictionary *_Nullable json, BugsnagApp *app, BugsnagDevice *device, BugsnagUser *user) {
    NSString *sessionId = json[BSGKeyId];
    NSDate *startedAt = [BSG_RFC3339DateTool dateFromString:json[BSGKeyStartedAt]];
    if (!sessionId || !startedAt) {
        return nil;
    }
    BugsnagSession *session = [[BugsnagSession alloc] initWithId:sessionId startedAt:startedAt user:user app:app device:device];
    NSDictionary *events = json[BSGKeyEvents];
    session.handledCount = [events[BSGKeyHandled] unsignedIntegerValue];
    session.unhandledCount = [events[BSGKeyUnhandled] unsignedIntegerValue];
    return session;
}
