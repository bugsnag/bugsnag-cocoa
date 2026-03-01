//
//  BugsnagInstrumentedHTTPRequest.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 24/02/2026.
//

#import <Foundation/Foundation.h>
#import "BugsnagNetworkRequestFailuresConfiguration.h"

/**
 * Represents an HTTP request that has been instrumented by BugSnag. This interface provides
 * access to the original request object, as well as methods to modify the information that is
 * reported to BugSnag.
 */
@interface BugsnagInstrumentedHTTPRequest : NSObject

+ (instancetype)initWithTransactionMetrics:(NSURLSessionTaskMetrics *)metrics config:(BugsnagNetworkRequestFailuresConfiguration *)config;

- (instancetype)init:(NSURLRequest *)request httpVersion:(NSString * _Nullable)httpVersion config:(BugsnagNetworkRequestFailuresConfiguration *)config;

/**
 * The original HTTP request object.
 */
- (NSURLRequest *)getRequest;

/**
 * The URL that will be reported to BugSnag for this request. This may be different from the
 * original request URL if it has been modified by a callback.
 */
- (_Nullable NSString *)getReportedUrl;

/**
 * Set the URL that will be reported to BugSnag for this request. Setting this to nil
 * will prevent the request from being reported at all.
 *
 * @param reportedUrl the URL to report
 */
- (void)setReportedUrl:(_Nullable NSString *)reportedUrl;

/**
 * The request body that will be reported to BugSnag for this request. This may be different
 * from the original request body if it has been modified by a callback.
 *
 * @return the reported request body
 */
- (_Nullable NSString *)getReportedRequestBody;

/**
 * Set the request body that will be reported to BugSnag for this request. Setting this to nil
 * will prevent the request body from being reported.
 *
 * @param requestBody the request body to report
 */
- (void)setReportedRequestBody:(_Nullable NSString *)requestBody;

@end
