//
//  BSGLoggerHelper.c
//  Bugsnag
//
//  Created by Daria Bialobrzeska on 26/05/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#include <stdarg.h>
#include "BSGLoggerHelper.h"

bool bsg_kslog_setLogFilename(const char *filename, bool overwrite)
{
    return kslog_setLogFilename(filename, overwrite);
}

void bsg_i_kslog_logCBasic(const char *fmt, ...)
{
    va_list(args);
    va_start(args, fmt);
    i_kslog_logCBasic(fmt, args);
    va_end(args);
}
