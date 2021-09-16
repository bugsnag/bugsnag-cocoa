//
//  BugsnagRequestMonitor.h
//  BugsnagRequestMonitor
//
//  Created by Karl Stenerud on 26.08.21.
//

#import <Foundation/Foundation.h>

@protocol BugsnagPlugin;

/**
 * BugsnagRequestMonitor produces network breadcrumbs for all URL requests made via NSURLSession.
 *
 * Note: This plugin will only report breadcrumbs in the following operating system versions:
 * - iOS 10.0+
 * - tvOS 10.0+
 * - macOS 10.12+
 */
@interface BugsnagRequestMonitor : NSObject<BugsnagPlugin>
@end
