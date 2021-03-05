//
//  BSGAppHangDetector.h
//  Bugsnag
//
//  Created by Nick Dowell on 01/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BugsnagConfiguration;
@class BugsnagEvent;
@class BugsnagThread;

NS_ASSUME_NONNULL_BEGIN

@protocol BSGAppHangDetectorDelegate;


@interface BSGAppHangDetector : NSObject

- (void)startWithDelegate:(id<BSGAppHangDetectorDelegate>)delegate;

@end


@protocol BSGAppHangDetectorDelegate <NSObject>

- (BugsnagConfiguration *)configuration;

- (BugsnagEvent *)appHangEventWithThreads:(NSArray<BugsnagThread *> *)threads;

- (void)notifyAppHangEvent:(BugsnagEvent *)event;

@end

NS_ASSUME_NONNULL_END
