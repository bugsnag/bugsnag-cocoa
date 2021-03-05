//
//  BSGAppHangDetector.h
//  Bugsnag
//
//  Created by Nick Dowell on 01/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface BSGAppHangDetector : NSObject

- (void)startWithConfiguration:(BugsnagConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
