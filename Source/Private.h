#ifndef BUGSNAG_PRIVATE_H
#define BUGSNAG_PRIVATE_H

#import "Bugsnag.h"
#import "BugsnagBreadcrumb.h"

@interface BugsnagBreadcrumbs ()
/**
 * Reads and return breadcrumb data currently stored on disk
 */
- (NSArray *_Nullable)cachedBreadcrumbs;
@end

@interface Bugsnag ()

/** Get the current Bugsnag configuration.
 *
 * This method returns nil if called before +startBugsnagWithApiKey: or
 * +startBugsnagWithConfiguration:, and otherwise returns the current
 * configuration for Bugsnag.
 *
 * @return The configuration, or nil.
 */
+ (BugsnagConfiguration *_Nullable)configuration;

@end

#endif // BUGSNAG_PRIVATE_H
