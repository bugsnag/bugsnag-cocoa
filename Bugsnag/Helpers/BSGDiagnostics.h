//
//  BSGDiagnostics.h
//  Bugsnag
//
//  Created by Robert Bartoszewski on 04/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BugsnagInternals.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

void logDiagnosticMessage(const char *message);
void BugsnagDiagnosticsWriteCrashReport(const BSG_KSCrashReportWriter * _Nonnull writer,
                                        bool requiresAsyncSafety);

#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END
