//
//  BugsnagCorrelation.h
//  Bugsnag
//
//  Created by Karl Stenerud on 13.05.24.
//  Copyright © 2024 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef BugsnagCorrelation_h
#define BugsnagCorrelation_h

NS_ASSUME_NONNULL_BEGIN

@interface BugsnagCorrelation: NSObject

@property (readwrite, nonatomic, strong, nullable) NSString *traceId;

@property (readwrite, nonatomic, strong, nullable) NSString *spanId;

@end

NS_ASSUME_NONNULL_END

#endif /* BugsnagCorrelation_h */
