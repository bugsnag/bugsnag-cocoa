//
//  BugsnagNetworkRequestFailuresConfiguration.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 11/01/2026.
//

#import "BugsnagNetworkRequestFailuresConfiguration.h"

@interface BugsnagNetworkRequestFailuresConfiguration ()
@property (nonatomic, strong) NSMutableIndexSet *errorCodes;
@property (nonatomic) NSMutableArray<BugsnagHttpResponseCallback> *responseCallbacks;
@end

@implementation BugsnagNetworkRequestFailuresConfiguration

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _errorCodes = [NSMutableIndexSet new];
    _responseCallbacks = [NSMutableArray new];
    _maxRequestBodyCapture = 0;
    _maxResponseBodyCapture = 0;

    return self;
}

- (void)addHttpErrorCode:(NSUInteger)errorCode {
    // TODO check for correct value
    [self.errorCodes addIndex:errorCode];
}


- (void)addHttpErrorCodes:(NSArray<NSNumber *> *)errorCodesArray {
    if (!errorCodesArray) {
        return;
    }
    for (id errorCode in errorCodesArray) {
        NSUInteger index = [errorCode unsignedIntegerValue];
        // TODO validate the value
        [self.errorCodes addIndex:index];
    }
}

- (void)removeHttpErrorCode:(NSUInteger)errorCode {
    [self.errorCodes removeIndex:errorCode];
}

- (void)addResponseCallback:(BugsnagHttpResponseCallback)callback {
        [self.responseCallbacks addObject:callback];
}

- (NSArray<BugsnagHttpResponseCallback> *)getResponseCallbacks {
    return self.responseCallbacks;
}

- (BOOL)shouldCaptureHttpErrorCode:(NSUInteger)errorCode {
    return [self.errorCodes containsIndex:errorCode];
}

@end
