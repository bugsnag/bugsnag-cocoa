//
//  BugsnagNetworkRequestFailuresConfiguration.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 11/01/2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class BugsnagInstrumentedHTTPResponse;

typedef BOOL (^BugsnagHttpResponseCallback)(BugsnagInstrumentedHTTPResponse *_Nonnull instrumentedResp);

/**
 * BugsnagNetworkRequestFailuresConfiguration allows configuring which HTTP response codes
 * should be treated as errors and sent to Bugsnag as handled exceptions.
 */
@interface BugsnagNetworkRequestFailuresConfiguration : NSObject

@property (nonatomic) NSUInteger maxRequestBodyCapture;
@property (nonatomic) NSUInteger maxResponseBodyCapture;
@property (nonatomic) BOOL enableNetworkBreadcrumbs;

- (void)addHttpErrorCode:(NSUInteger)errorCode;
- (void)addHttpErrorCodes:(NSArray<NSNumber *> *)errorCodesArray;
- (void)removeHttpErrorCode:(NSUInteger)errorCode;

- (void)addResponseCallback:(BugsnagHttpResponseCallback)callback;
- (NSArray<BugsnagHttpResponseCallback> *)getResponseCallbacks;

- (BOOL)shouldCaptureHttpErrorCode:(NSUInteger)errorCode;

@end

NS_ASSUME_NONNULL_END
