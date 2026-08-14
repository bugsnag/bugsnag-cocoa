//
//  BugsnagSharedSessionProxy.h
//  BugsnagNetworkRequestPlugin
//
//  Created by Daria Bialobrzeska on 06/03/2026.
//

#import <Foundation/Foundation.h>

/**
 *  A proxy for NSURLSession that ignores finishTasksAndInvalidate and invalidateAndCancel calls
 */
@interface BugsnagSharedSessionProxy: NSProxy

- (id)initWithSession:(NSURLSession *)session;

@end
