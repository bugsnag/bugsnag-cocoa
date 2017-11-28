//
//  BugsnagSessionTrackingPayload.m
//  Bugsnag
//
//  Created by Jamie Lynch on 27/11/2017.
//  Copyright © 2017 Bugsnag. All rights reserved.
//

#import "BugsnagSessionTrackingPayload.h"
#import "BugsnagCollections.h"
#import "BugsnagNotifier.h"
#import "Bugsnag.h"
#import "BugsnagKeys.h"

@interface Bugsnag ()
+ (BugsnagNotifier *)notifier;
@end

@implementation BugsnagSessionTrackingPayload

- (NSDictionary *)toJson {
    
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *sessionData = [NSMutableArray new];
    
    for (BugsnagSession *session in self.sessions) {
        [sessionData addObject:[session toJson]];
    }
    BSGDictInsertIfNotNil(dict, sessionData, @"sessions");
    BSGDictSetSafeObject(dict, [Bugsnag notifier].details, BSGKeyNotifier);
    
    // TODO serialise below!
    
//    // Top level info that is unlikely change between sessions on one device (in the notifier batch period)
//    "device": {
//        "hostname": "Mikes-Ipad",
//        "jailbroken": false,
//        "manufacturer": "Apple",
//        "model": "iPad3,2",
//        "modelNumber": "123",
//        "osName": "iOS",
//        "osVersion": "7.0.4",
//        "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.98 Safari/537.36"
//    },
//    "app": {
//        "type": "sidekiq",
//        "releaseStage": "production",
//        "version": "1.1",
//        "versionCode": 123,
//        "bundleVersion": "123",
//        "codeBundleId": "1111"
//    },
    
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
