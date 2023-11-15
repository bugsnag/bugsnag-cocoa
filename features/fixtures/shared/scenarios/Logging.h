//
//  Logging.h
//  iOSTestApp
//
//  Created by Karl Stenerud on 02.11.23.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>

void logDebugObjC(NSString *format, ...);
void logInfoObjC(NSString *format, ...);
void logWarnObjC(NSString *format, ...);
void logErrorObjC(NSString *format, ...);

//#define logInfo(FMT, ...)  logInfoObjC(FMT, __VA_ARGS__)
//#define logWarn(FMT, ...)  logWarnObjC(FMT, __VA_ARGS__)
//#define logError(FMT, ...) logErrorObjC(FMT, __VA_ARGS__)

#define logDebug  logDebugObjC
#define logInfo  logInfoObjC
#define logWarn  logWarnObjC
#define logError logErrorObjC
