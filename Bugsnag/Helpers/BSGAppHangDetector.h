//
//  BSGAppHangDetector.h
//  Bugsnag
//
//  Created by Nick Dowell on 01/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "BSGDefines.h"

#if BSG_HAVE_APP_HANG_DETECTION

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class BugsnagEvent;
@class BugsnagThread;

NS_ASSUME_NONNULL_BEGIN

@protocol BSGAppHangDetectorDelegate;


BSG_OBJC_DIRECT_MEMBERS
@interface BSGAppHangDetector : NSObject

- (void)startWithDelegate:(id<BSGAppHangDetectorDelegate>)delegate;

- (void)stop;

@end


@protocol BSGAppHangDetectorDelegate <NSObject>

@property (readonly) BugsnagConfiguration *configuration;

- (void)appHangDetectedAtDate:(NSDate *)date withThreads:(NSArray<BugsnagThread *> *)threads systemInfo:(NSDictionary *)systemInfo;

- (void)appHangEnded;

@end

NS_ASSUME_NONNULL_END

#endif
