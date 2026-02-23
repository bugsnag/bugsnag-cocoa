//
//  BugsnagNetworkRequestFailuresConfiguration.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 11/01/2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * BugsnagNetworkRequestFailuresConfiguration allows configuring which HTTP response codes
 * should be treated as errors and sent to Bugsnag as handled exceptions.
 */
@interface BugsnagNetworkRequestFailuresConfiguration : NSObject

@property (nonatomic) NSNumber *maxRequestBodyCapture;
@property (nonatomic) NSNumber *maxResponseBodyCapture;

- (void)addHttpErrorCode:(NSNumber *)errorCode;
- (void)addHttpErrorCodes:(NSArray<NSNumber *> *)errorCodesArray;
- (void)removeHttpErrorCode:(NSNumber *)errorCode;

- (BOOL)shouldCaptureHttpErrorCode:(NSNumber *)errorCode;

@end

NS_ASSUME_NONNULL_END
