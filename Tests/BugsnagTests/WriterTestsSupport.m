//
//  WriterTestsSupport.m
//  Bugsnag
//
//  Created by Robert B on 24/03/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "WriterTestsSupport.h"

// Defined in BSG_KSCrashReport.c
void bsg_kscrw_i_prepareReportWriter(BSG_KSCrashReportWriter *const writer, BSG_KSJSONEncodeContext *const context);

static int addJSONData(const char *data, size_t length, NSMutableData *userData) {
    [userData appendBytes:data length:length];
    return BSG_KSJSON_OK;
}

id bsg_JSONObject(void (^ block)(BSG_KSCrashReportWriter *writer)) {
    NSMutableData *data = [NSMutableData data];
    BSG_KSJSONEncodeContext encodeContext;
    BSG_KSCrashReportWriter reportWriter;
    bsg_kscrw_i_prepareReportWriter(&reportWriter, &encodeContext);
    bsg_ksjsonbeginEncode(&encodeContext, false, (BSG_KSJSONAddDataFunc)addJSONData, (__bridge void *)data);
    block(&reportWriter);
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}
