// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "BSFPRTraceBackgroundActivityTracker.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//#import "BSFPRAppActivityTracker.h"

@interface BSFPRTraceBackgroundActivityTracker ()

@property(nonatomic, readwrite) BSFPRTraceState traceBackgroundState;

@end

@implementation BSFPRTraceBackgroundActivityTracker

- (instancetype)init {
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:[UIApplication sharedApplication]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication sharedApplication]];
  }
  return self;
}

- (void)dealloc {
  // Remove all the notification observers registered.
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIApplicationDelegate events

/**
 * This gets called whenever the app becomes active.
 *
 * @param notification Notification received during app launch.
 */
- (void)applicationDidBecomeActive:(NSNotification *)notification {
  if (_traceBackgroundState == BSFPRTraceStateBackgroundOnly) {
    _traceBackgroundState = BSFPRTraceStateBackgroundAndForeground;
  }
}

/**
 * This gets called whenever the app enters background.
 *
 * @param notification Notification received when the app enters background.
 */
- (void)applicationDidEnterBackground:(NSNotification *)notification {
  if (_traceBackgroundState == BSFPRTraceStateForegroundOnly) {
    _traceBackgroundState = BSFPRTraceStateBackgroundAndForeground;
  }
}

@end
