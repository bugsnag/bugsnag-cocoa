//
//  BugsnagInstrumentedHTTPResponse.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 27/02/2026.
//

#import <Foundation/Foundation.h>
#import "BugsnagNetworkRequestFailuresConfiguration.h"

/**
 * Represents an HTTP response that has been instrumented by BugSnag. This interface provides
 * access to the original request and response objects, as well as methods to modify the
 * information that is reported to BugSnag.
 */
@interface BugsnagInstrumentedHTTPResponse : NSObject

+ (instancetype)initWithTransactionMetrics:(NSURLSessionTaskMetrics *)metrics config:(BugsnagNetworkRequestFailuresConfiguration *)config;

- (instancetype)init:(NSURLResponse *)response config:(BugsnagNetworkRequestFailuresConfiguration *)config;

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
- (NSInteger) getStatusCode;

/**
 * The response body that will be reported to BugSnag for this response. This may be different
 * from the original response body if it has been modified by a callback.
 *
 * @return the reported response body
 */
- (NSString * _Nullable) getReportedResponseBody;

/**
 * Set the response body that will be reported to BugSnag for this response. Setting this to nil
 * will prevent the response body from being reported.
 *
 * @param responseBody the response body to report
 */
- (void) setReportedResponseBody:(NSString * _Nullable)responseBody;

/**
 * Override whether this request/response should be reported as a breadcrumb. This defaults
 * to the value passed to BugsnagNetworkRequestFailuresConfiguration's enableNetworkBreadcrumbs, but
 * cannot override whether notifier's breadcrumbs are enabled.
 *
 * @param isBreadcrumbReported NO if a breadcrumb should not be reported
 */
- (void) setBreadcrumbReported:(BOOL)isBreadcrumbReported;

/**
 * Check whether a breadcrumb will be reported for this response.
 *
 * @return YES if a breadcrumb will be reported
 */
- (BOOL) isBreadcrumbReported;

@end
