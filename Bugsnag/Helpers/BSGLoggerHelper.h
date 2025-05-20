//
//  BSGLoggerHelper.h
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 23/05/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

//** File needed to expose hidden symbols from KSCrash
// * to enable logging from test fixtures.
//

#ifndef BSGLoggerHelper_h
#define BSGLoggerHelper_h

#include <stdbool.h>
#include <Bugsnag/BugsnagDefines.h>
#include "KSLogger.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Set the filename to log to.
 *
 * @param filename The file to write to (NULL = write to stdout).
 *
 * @param overwrite If true, overwrite the log file.
 */
BUGSNAG_EXTERN
bool bsg_kslog_setLogFilename(const char *filename, bool overwrite);

BUGSNAG_EXTERN
void bsg_i_kslog_logCBasic(const char *fmt, ...);

#ifdef __cplusplus
}
#endif

#endif // BSGLoggerHelper_h
