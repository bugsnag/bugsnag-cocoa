//
//  BugsnagApp.m
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagApp.h"
#import "BugsnagKeys.h"
#import "BugsnagConfiguration.h"
#import "BugsnagCollections.h"

@implementation BugsnagApp

+ (BugsnagApp *)appWithDictionary:(NSDictionary *)event
                           config:(BugsnagConfiguration *)config
{
    BugsnagApp *app = [BugsnagApp new];
    [self populateFields:app dictionary:event config:config];
    return app;
}

+ (void)populateFields:(BugsnagApp *)app
            dictionary:(NSDictionary *)event
                config:(BugsnagConfiguration *)config
{
    NSDictionary *system = event[BSGKeySystem];
    app.id = system[@"CFBundleIdentifier"];
    app.bundleVersion = system[@"CFBundleVersion"];
    app.dsymUuid = system[@"app_uuid"];
    app.version = [event valueForKeyPath:@"user.config.appVersion"] ?: system[@"CFBundleShortVersionString"];
    app.releaseStage = [event valueForKeyPath:@"user.config.releaseStage"] ?: config.releaseStage;
    app.codeBundleId = config.codeBundleId;
    app.type = config.appType;
}

- (NSDictionary *)toDict
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    BSGDictInsertIfNotNil(dict, self.bundleVersion, @"bundleVersion");
    BSGDictInsertIfNotNil(dict, self.codeBundleId, @"codeBundleId");
    BSGDictInsertIfNotNil(dict, self.id, @"id");
    BSGDictInsertIfNotNil(dict, self.releaseStage, @"releaseStage");
    BSGDictInsertIfNotNil(dict, self.type, @"type");
    BSGDictInsertIfNotNil(dict, self.version, @"version");

    if (self.dsymUuid != nil) {
        BSGDictInsertIfNotNil(dict, @[self.dsymUuid], @"dsymUUIDs");
    }
    return dict;
}

@end
