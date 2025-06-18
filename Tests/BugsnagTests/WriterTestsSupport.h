//
//  WriterTestsSupport.h
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "Bugsnag.h"
#import "KSJSONCodec.h"
#import "KSCrashReportWriter.h"

void prepareReportWriter(KSCrashReportWriter *const writer, KSJSONEncodeContext *const context);

id bsg_JSONObject(void (^ block)(KSCrashReportWriter *writer));
