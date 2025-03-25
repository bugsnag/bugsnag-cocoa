//
//  WriterTestsSupport.h
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "Bugsnag.h"
#import "BSG_KSJSONCodec.h"

id bsg_JSONObject(void (^ block)(BSG_KSCrashReportWriter *writer));
