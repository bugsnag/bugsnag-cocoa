//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "Scenario.h"
#import <Bugsnag/Bugsnag.h>
#import <BugsnagNetworkRequestPlugin/BugsnagNetworkRequestPlugin.h>

extern bool bsg_kslog_setLogFilename(const char *filename, bool overwrite);

extern void bsg_i_kslog_logCBasic(const char *fmt, ...) __printflike(1, 2);

static inline void kslog(const char *message) {
    bsg_i_kslog_logCBasic("%s", message);
}
