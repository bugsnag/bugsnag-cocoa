//
//  BSGWatchKit.h
//  Bugsnag
//
//  Created by Karl Stenerud on 10.05.22.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

#include "BSGDefines.h"

#if BSG_HAVE_WATCHKIT

#define UIApplicationWillTerminateNotification        @"UIApplicationWillTerminateNotification"
#define WKApplicationWillEnterForegroundNotification  @"WKApplicationWillEnterForegroundNotification"
#define WKApplicationDidBecomeActiveNotification      @"WKApplicationDidBecomeActiveNotification"
#define WKApplicationWillResignActiveNotification     @"WKApplicationWillResignActiveNotification"
#define WKApplicationDidEnterBackgroundNotification   @"WKApplicationDidEnterBackgroundNotification"

#endif
