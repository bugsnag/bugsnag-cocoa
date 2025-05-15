//
//  BugsnagApp.m
//  Bugsnag
//
//  Created by Jamie Lynch on 01/04/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BugsnagApp.h"

#import "BSGKeys.h"
#import "BSGRunContext.h"
#import "BSGSystemInfo.h"
#import "BugsnagCollections.h"
#import "BugsnagConfiguration.h"
#import "KSCrashReportFields.h"

/**
 * Parse an event dictionary representation for App-specific metadata.
 *
 * @returns A dictionary of app-specific metadata
 */
NSDictionary *BSGParseAppMetadata(NSDictionary *event) {
    NSMutableDictionary *app = [NSMutableDictionary new];

    NSMutableString *execPathKey = [NSMutableString string];
    [execPathKey appendString:@"system."];
    [execPathKey appendString:KSCrashField_Executable];
    app[@"name"] = [event valueForKeyPath:execPathKey];

    app[@"runningOnRosetta"] = [event valueForKeyPath:@"system." @BSG_SystemField_Translated];
    return app;
}

NSDictionary *BSGAppMetadataFromRunContext(const struct BSGRunContext *context) {
    NSMutableDictionary *app = [NSMutableDictionary dictionary];
    if (context->memoryLimit) {
        app[BSGKeyFreeMemory] = @(context->memoryAvailable);
        app[BSGKeyMemoryLimit] = @(context->memoryLimit);
    }
    if (context->memoryFootprint) {
        app[BSGKeyMemoryUsage] = @(context->memoryFootprint);
    }
    return app;
}

@implementation BugsnagApp

+ (BugsnagApp *)deserializeFromJson:(NSDictionary *)json {
    BugsnagApp *app = [BugsnagApp new];
    if (json != nil) {
        app.binaryArch = json[@"binaryArch"];
        app.bundleVersion = json[@"bundleVersion"];
        app.codeBundleId = json[@"codeBundleId"];
        app.id = json[@"id"];
        app.releaseStage = json[@"releaseStage"];
        app.type = json[@"type"];
        app.version = json[@"version"];
        app.dsymUuid = [json[@"dsymUUIDs"] firstObject];
    }
    return app;
}

+ (BugsnagApp *)appWithDictionary:(NSDictionary *)event
                           config:(BugsnagConfiguration *)config
                     codeBundleId:(NSString *)codeBundleId
{
    BugsnagApp *app = [BugsnagApp new];
    [self populateFields:app
              dictionary:event
                  config:config
            codeBundleId:codeBundleId];
    return app;
}

+ (void)populateFields:(BugsnagApp *)app
            dictionary:(NSDictionary *)event
                config:(BugsnagConfiguration *)config
          codeBundleId:(NSString *)codeBundleId
{
    NSDictionary *system = event[BSGKeySystem];
    app.id = system[KSCrashField_BundleID];
    app.binaryArch = system[@BSG_SystemField_BinaryArch];
    app.bundleVersion = system[KSCrashField_BundleVersion];
    app.dsymUuid = system[KSCrashField_AppUUID];
    app.version = system[KSCrashField_BundleShortVersion];
    app.codeBundleId = [event valueForKeyPath:@"user.state.app.codeBundleId"] ?: codeBundleId;
    [app setValuesFromConfiguration:config];
}

- (void)setValuesFromConfiguration:(BugsnagConfiguration *)configuration
{
    if (configuration.appType) {
        self.type = configuration.appType;
    }
    if (configuration.appVersion) {
        self.version = configuration.appVersion;
    }
    if (configuration.bundleVersion) {
        self.bundleVersion = configuration.bundleVersion;
    }
    if (configuration.releaseStage) {
        self.releaseStage = configuration.releaseStage;
    }
}

- (NSDictionary *)toDict
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"binaryArch"] = self.binaryArch;
    dict[@"bundleVersion"] = self.bundleVersion;
    dict[@"codeBundleId"] = self.codeBundleId;
    dict[@"dsymUUIDs"] = BSGArrayWithObject(self.dsymUuid);
    dict[@"id"] = self.id;
    dict[@"releaseStage"] = self.releaseStage;
    dict[@"type"] = self.type;
    dict[@"version"] = self.version;
    return dict;
}

@end
