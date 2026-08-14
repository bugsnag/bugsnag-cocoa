//
//  BugsnagNetworkRequestPlugin.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Karl Stenerud on 26.08.21.
//
#import <Foundation/Foundation.h>

#import <Bugsnag/BugsnagPlugin.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestFailuresConfiguration.h>
#import <BugsnagNetworkRequestPlugin/BugsnagInstrumentedHTTPResponse.h>
#import <BugsnagNetworkRequestPlugin/BugsnagInstrumentedHTTPRequest.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * BugsnagNetworkRequestPlugin produces network breadcrumbs for all URL requests made via NSURLSession.
 */
API_AVAILABLE(macosx(10.12), ios(10.0), watchos(3.0), tvos(10.0))
@interface BugsnagNetworkRequestPlugin : NSObject<BugsnagPlugin>

@property (nonatomic, nullable, readonly) BugsnagNetworkRequestFailuresConfiguration* configuration;

+ (instancetype)initWithConfiguration:(BugsnagNetworkRequestFailuresConfiguration * _Nullable)configuration
                enableNetworkBreadcrumbs:(BOOL)enableNetworkBreadcrumbs
    NS_SWIFT_NAME(initWithConfiguration(configuration:enableNetworkBreadcrumbs:));

@end
NS_ASSUME_NONNULL_END
