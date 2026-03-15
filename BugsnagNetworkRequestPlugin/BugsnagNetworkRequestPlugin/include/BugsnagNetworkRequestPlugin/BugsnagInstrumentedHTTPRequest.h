//
//  BugsnagInstrumentedHTTPRequest.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 24/02/2026.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/BugsnagRequest.h>

@class BugsnagNetworkRequestFailuresConfiguration;

NS_ASSUME_NONNULL_BEGIN
/**
 * Represents an HTTP request that has been instrumented by BugSnag. This interface provides
 * access to the original request object, as well as methods to modify the information that is
 * reported to BugSnag.
 */
@interface BugsnagInstrumentedHTTPRequest : NSObject

+ (instancetype)init:(NSURLRequest * _Nullable)request
         httpVersion:(NSString * _Nullable)httpVersion
              config:(BugsnagNetworkRequestFailuresConfiguration *)config
API_AVAILABLE(macos(10.12));

/**
 * The original HTTP request object.
 */
- (NSURLRequest * _Nullable)getRequest;

/**
 * The URL that will be reported to BugSnag for this request. This may be different from the
 * original request URL if it has been modified by a callback.
 */
- (NSString * _Nullable)getReportedUrl;

/**
 * Set the URL that will be reported to BugSnag for this request. Setting this to nil
 * will prevent the request from being reported at all.
 *
 * @param reportedUrl the URL to report
 */
- (void)setReportedUrl:(NSString * _Nullable)reportedUrl;

/**
 * The request body that will be reported to BugSnag for this request. This may be different
 * from the original request body if it has been modified by a callback.
 *
 * @return the reported request body
 */
- (NSString * _Nullable)getReportedRequestBody;

/**
 * Set the request body that will be reported to BugSnag for this request. Setting this to nil
 * will prevent the request body from being reported.
 *
 * @param requestBody the request body to report
 */
- (void)setReportedRequestBody:(NSString * _Nullable)requestBody;

- (BugsnagRequest *)getBugsnagRequest;

@end

NS_ASSUME_NONNULL_END
