#import "BSGConfigurationBuilder.h"
#import "BugsnagConfiguration.h"

NSString *const BSGAutoCollectBreadcrumbsKey = @"autoBreadcrumbs";
NSString *const BSGAutoCaptureSessionsKey = @"autoSessions";

/**
 * Validate and set a value on config if the value is of the correct type.
 * Remove the value from options after successful validation.
 *
 * @return config or nil if the value is not of the correct type
 */
BugsnagConfiguration *BSGValidateAndSetStringOption(BugsnagConfiguration *config, NSMutableDictionary *options, NSString *key);
/**
 * Validate and set a value on config if the value is a boolean.
 * Remove the value from options after successful validation.
 *
 * @return config or nil if the value is a boolean
 */
BugsnagConfiguration *BSGValidateAndSetBooleanOption(BugsnagConfiguration *config, NSMutableDictionary *options, NSString *key);

/**
 * Validate and set notifyReleaseStages on config if the value is an array of
 * strings.
 * Remove the value from options after successful validation.
 *
 * @return config or nil if the value or contained values are not of the correct
 * type
 */
BugsnagConfiguration *BSGValidateAndSetNotifyReleaseStages(BugsnagConfiguration *config, NSMutableDictionary *options);

/**
 * Validate and set notifyURL and sessionURL on config if the value is a
 * dictionary containing exactly two values for keys "notify" and "sessions".
 * Remove the value from options after successful validation.
 *
 * @return config or nil if the value or contained values are not of the correct
 * type or name, to avoid data leakage to the hosted version from on-premise.
 */
BugsnagConfiguration *BSGValidateAndSetEndpoints(BugsnagConfiguration *config, NSMutableDictionary *options);

@implementation BSGConfigurationBuilder

+ (BugsnagConfiguration *)configurationFromOptions:(NSDictionary *)options {
    BugsnagConfiguration *config = [BugsnagConfiguration new];
    NSMutableDictionary *properties = [options mutableCopy];
    config = BSGValidateAndSetStringOption(config, properties, NSStringFromSelector(@selector(apiKey)));
    if (config.apiKey.length == 0) {
        // The API key is not valid
        return nil;
    }
    config = BSGValidateAndSetBooleanOption(config, properties, NSStringFromSelector(@selector(autoNotify)));
    config = BSGValidateAndSetBooleanOption(config, properties, BSGAutoCollectBreadcrumbsKey);
    config = BSGValidateAndSetBooleanOption(config, properties, BSGAutoCaptureSessionsKey);
    config = BSGValidateAndSetBooleanOption(config, properties, NSStringFromSelector(@selector(reportOOMs)));
    config = BSGValidateAndSetBooleanOption(config, properties, NSStringFromSelector(@selector(reportBackgroundOOMs)));
    config = BSGValidateAndSetStringOption(config, properties, NSStringFromSelector(@selector(releaseStage)));
    config = BSGValidateAndSetNotifyReleaseStages(config, properties);
    config = BSGValidateAndSetEndpoints(config, properties);
    if (properties.count > 0) {
        // The collection contains values unsupported in BugsnagConfiguration
        return nil;
    }
    return config;
}

@end

static BOOL BSGValueIsBoolean(id object) {
    return [object isKindOfClass:[NSNumber class]]
    && CFGetTypeID((__bridge CFTypeRef)object) == CFBooleanGetTypeID();
}

NSString *BSGTransformOptionToPropertyName(NSString *option) {
    if ([option isEqualToString:BSGAutoCollectBreadcrumbsKey]) {
        return NSStringFromSelector(@selector(automaticallyCollectBreadcrumbs));
    } else if ([option isEqualToString:BSGAutoCaptureSessionsKey]) {
        return NSStringFromSelector(@selector(shouldAutoCaptureSessions));
    }
    return option;
}

BugsnagConfiguration *BSGValidateAndSetStringOption(BugsnagConfiguration *config, NSMutableDictionary *options, NSString *key) {
    if ([options[key] isKindOfClass:[NSString class]]) {
        [config setValue:options[key] forKey:key];
    } else if (options[key]) {
        return nil;
    }
    [options removeObjectForKey:key];
    return config;
}

BugsnagConfiguration *BSGValidateAndSetBooleanOption(BugsnagConfiguration *config, NSMutableDictionary *options, NSString *key) {
    if (BSGValueIsBoolean(options[key])) {
        [config setValue:options[key] forKey:BSGTransformOptionToPropertyName(key)];
    } else if (options[key]) {
        return nil;
    }
    [options removeObjectForKey:key];
    return config;
}

BugsnagConfiguration *BSGValidateAndSetNotifyReleaseStages(BugsnagConfiguration *config, NSMutableDictionary *options) {
    NSString *const notifyReleaseStagesKey = NSStringFromSelector(@selector(notifyReleaseStages));
    if (options[notifyReleaseStagesKey] && [options[notifyReleaseStagesKey] isKindOfClass:[NSArray class]]) {
        NSArray *notifyReleaseStages = options[notifyReleaseStagesKey];
        for (id stage in notifyReleaseStages) {
            if (![stage isKindOfClass:[NSString class]]) {
                return nil;
            }
        }
        config.notifyReleaseStages = notifyReleaseStages;
    } else if (options[notifyReleaseStagesKey]) {
        return nil;
    }
    [options removeObjectForKey:notifyReleaseStagesKey];
    return config;
}

BugsnagConfiguration *BSGValidateAndSetEndpoints(BugsnagConfiguration *config, NSMutableDictionary *options) {
    NSString *const endpointsKey = @"endpoints";
    NSString *const notifyEndpointKey = @"notify";
    NSString *const sessionsEndpointKey = @"sessions";
    if (options[endpointsKey] && [options[endpointsKey] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *endpoints = options[endpointsKey];
        if (endpoints.count == 2
            && [endpoints[notifyEndpointKey] isKindOfClass:[NSString class]]
            && [endpoints[sessionsEndpointKey] isKindOfClass:[NSString class]]) {
            NSString *notifyEndpoint = endpoints[notifyEndpointKey];
            NSString *sessionsEndpoint = endpoints[sessionsEndpointKey];
            if (notifyEndpoint.length > 0 && sessionsEndpoint.length > 0) {
                [config setEndpointsForNotify:endpoints[notifyEndpointKey]
                                     sessions:endpoints[sessionsEndpointKey]];
            } else {
                return nil;
            }
        } else {
            return nil;
        }
    } else if (options[endpointsKey]) {
        return nil;
    }
    [options removeObjectForKey:endpointsKey];
    return config;
}
