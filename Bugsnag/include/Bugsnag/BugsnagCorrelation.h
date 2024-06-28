//
//  BugsnagCorrelation.h
//  Bugsnag
//
//  Created by Karl Stenerud on 13.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Bugsnag/BugsnagDefines.h>

NS_ASSUME_NONNULL_BEGIN

BUGSNAG_EXTERN
@interface BugsnagCorrelation: NSObject

@property (readwrite, nonatomic, strong, nullable) NSString *traceId;

@property (readwrite, nonatomic, strong, nullable) NSString *spanId;

@end

NS_ASSUME_NONNULL_END
