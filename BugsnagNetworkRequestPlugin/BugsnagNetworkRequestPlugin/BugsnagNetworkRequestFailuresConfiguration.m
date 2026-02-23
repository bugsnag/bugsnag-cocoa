//
//  BugsnagNetworkRequestFailuresConfiguration.m
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 11/01/2026.
//

#import "BugsnagNetworkRequestFailuresConfiguration.h"

static const NSUInteger httpBodySizeLimit = 1000000;

@interface BugsnagNetworkRequestFailuresConfiguration ()
@property (nonatomic, strong) NSMutableIndexSet *errorCodes;
@end

@implementation BugsnagNetworkRequestFailuresConfiguration

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    _errorCodes = [NSMutableIndexSet new];
    _maxRequestBodyCapture = 0;
    _maxResponseBodyCapture = 0;

    return self;
}

- (void)addHttpErrorCode:(NSNumber *)errorCode {
    if (!errorCode) {
        return;
    }

    NSUInteger index = [errorCode unsignedIntegerValue];
    // todo check for correct value
    [self.errorCodes addIndex:index];
}


- (void)addHttpErrorCodes:(NSArray<NSNumber *> *)errorCodesArray {
    if (!errorCodesArray) {
        return;
    }
    for (id errorCode in errorCodesArray) {
        NSUInteger index = [errorCode unsignedIntegerValue];
        [self.errorCodes addIndex:index];
    }
}

- (void)removeHttpErrorCode:(NSNumber *)errorCode {
    if (!errorCode) {
        return;
    }
    NSUInteger index = [errorCode unsignedIntegerValue];
    [self.errorCodes removeIndex:index];
}


- (BOOL)shouldCaptureHttpErrorCode:(NSNumber *)errorCode {
    if (!errorCode) {
        return NO;
    }

    NSUInteger index = [errorCode unsignedIntegerValue];
    return [self.errorCodes containsIndex:index];
}

@end
