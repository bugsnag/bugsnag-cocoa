//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "Scenario.h"
#import <Bugsnag/Bugsnag.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin.h>

extern bool bsg_kslog_setLogFilename(const char *filename, bool overwrite);
