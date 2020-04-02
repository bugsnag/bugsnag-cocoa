//
//  BugsnagSessionTrackingPayload.m
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagCollections.h"
#import "BugsnagClient.h"
#import "BugsnagClientInternal.h"
#import "Bugsnag.h"
#import "BugsnagKeys.h"
#import "BSG_KSSystemInfo.h"
#import "BugsnagConfiguration.h"
#import "BugsnagKSCrashSysInfoParser.h"
#import "Private.h"
#import "BugsnagApp.h"

@interface BugsnagSession ()
- (NSDictionary *)toJson;
@end

@interface Bugsnag ()
+ (BugsnagClient *)client;
@end

@interface BugsnagDevice ()
+ (BugsnagDevice *)deviceWithDictionary:(NSDictionary *)event;
- (NSDictionary *)toDict;
@end

@interface BugsnagApp ()
+ (BugsnagApp *)appWithDictionary:(NSDictionary *)event
                           config:(BugsnagConfiguration *)config;

- (NSDictionary *)toDict;
@end

@interface BugsnagSessionTrackingPayload ()
@property (nonatomic) BugsnagConfiguration *config;
@end

@implementation BugsnagSessionTrackingPayload

- (instancetype)initWithSessions:(NSArray<BugsnagSession *> *)sessions
                          config:(BugsnagConfiguration *)config
{
    if (self = [super init]) {
        _sessions = sessions;
        _config = config;
    }
    return self;
}

- (NSMutableDictionary *)toJson
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *sessionData = [NSMutableArray new];

    for (BugsnagSession *session in self.sessions) {
        [sessionData addObject:[session toJson]];
    }
    BSGDictInsertIfNotNil(dict, sessionData, @"sessions");
    BSGDictSetSafeObject(dict, [Bugsnag client].details, BSGKeyNotifier);

    // app/device data collection relies on KSCrash reports,
    // need to mimic the JSON structure here
    NSDictionary *systemInfo = [BSG_KSSystemInfo systemInfo];
    NSDictionary *event = [self appInfo:systemInfo config:self.config];
    BugsnagApp *app = [BugsnagApp appWithDictionary:event config:self.config];
    BSGDictSetSafeObject(dict, [app toDict], @"app");

    BugsnagDevice *device = [BugsnagDevice deviceWithDictionary:@{@"system": systemInfo}];
    BSGDictSetSafeObject(dict, [device toDict], @"device");
    return dict;
}

- (NSDictionary *)appInfo:(NSDictionary *)systemInfo
                   config:(BugsnagConfiguration *)config
{
    NSMutableDictionary *data = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(data, config.releaseStage, @"releaseStage");
    BSGDictInsertIfNotNil(data, config.appVersion, @"appVersion");

    return @{
            @"system": systemInfo,
            @"user": @{
                    @"config": data
            }
    };
}

@end
