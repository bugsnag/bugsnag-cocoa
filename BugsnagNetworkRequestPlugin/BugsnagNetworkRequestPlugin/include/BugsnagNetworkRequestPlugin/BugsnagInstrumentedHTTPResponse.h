//
//  BugsnagInstrumentedHTTPResponse.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 27/02/2026.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/BugsnagResponse.h>
#import <Bugsnag/BugsnagConfiguration.h>

@class BugsnagNetworkRequestFailuresConfiguration;
@class BugsnagInstrumentedHTTPRequest;

NS_ASSUME_NONNULL_BEGIN
/**
 * Represents an HTTP response that has been instrumented by BugSnag. This interface provides
 * access to the original request and response objects, as well as methods to modify the
 * information that is reported to BugSnag.
 */
@interface BugsnagInstrumentedHTTPResponse : NSObject

+ (instancetype)init:(NSURLResponse * _Nullable)response
              config:(BugsnagNetworkRequestFailuresConfiguration *)config
              enableNetworkBreadcrumbs:(BOOL)enableNetworkBreadcrumbs
    API_AVAILABLE(macos(10.12));

@property (nonatomic, nullable, assign) BugsnagInstrumentedHTTPRequest *relatedRequest;

/**
 * The original HTTP response object, if one was received. This may be nil if the
 * request failed to produce a response (e.g. due to a network error).
 *
 * @return the original response, or nil
 */
- (NSURLResponse * _Nullable)getResponse;

/**
 * Reported http status code.
 */
- (NSInteger)getStatusCode;

/**
 * Add instrumented request related to this response.
 * Added here for the purpose of onResponse callback.
 */
- (void)setInstrumentedRequest:(BugsnagInstrumentedHTTPRequest *)request;

/**
 * The response body that will be reported to BugSnag for this response. This may be different
 * from the original response body if it has been modified by a callback.
 *
 * @return the reported response body
 */
- (NSString * _Nullable)getReportedResponseBody;

/**
 * Set the response body that will be reported to BugSnag for this response. Setting this to nil
 * will prevent the response body from being reported.
 *
 * @param responseBody the response body to report
 */
- (void)setReportedResponseBody:(NSString * _Nullable)responseBody;

/**
 * Override whether this request/response should be reported as a breadcrumb. This defaults
 * to the value passed to BugsnagNetworkRequestFailuresConfiguration's enableNetworkBreadcrumbs, but
 * cannot override whether notifier's breadcrumbs are enabled.
 *
 * @param isBreadcrumbReported NO if a breadcrumb should not be reported
 */
- (void)setBreadcrumbReported:(BOOL)isBreadcrumbReported;

/**
 * Check whether a breadcrumb will be reported for this response.
 *
 * @return YES if a breadcrumb will be reported
 */
- (BOOL)isBreadcrumbReported;

/**
 * Set an onErrorCallback that can customise Bugsnag Event
 * created as a consequence to this response.. Setting this to nil will remove any existing error callback.
 *
 * @param onErrorCallback the error callback to customise HTTP events
 */
- (void)setErrorCallback:(BugsnagOnErrorBlock _Nullable)onErrorCallback;

/**
 * Return the error callback if one has been set.
 *
 * @return the error callback for this response
 */
- (BugsnagOnErrorBlock _Nullable)getErrorCallback;

- (BugsnagResponse *)getBugsnagResponse;

@end
NS_ASSUME_NONNULL_END
