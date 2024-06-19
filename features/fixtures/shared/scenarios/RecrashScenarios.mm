//
//  BadCrashHandlerScenario.h
//  iOSTestApp
//
//  Created by Nick on 2/12/21.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#import "Scenario.h"
#import "Logging.h"

#import <stdexcept>

#define THROW_CPP_EXCEPTION throw std::runtime_error("err")
#define THROW_OBJC_EXCEPTION \
    [[NSException exceptionWithName:NSRangeException \
                             reason:@"Something is out of range" \
                           userInfo:nil] raise]
#define CAUSE_MACH_EXCEPTION volatile int *ptr = NULL; *ptr = 42
#define RAISE_SIGNAL abort()

extern "C" void OnCrashAbort(const BSG_KSCrashReportWriter *writer) {
    RAISE_SIGNAL;
}

extern "C" void OnCrashBadAccess(const BSG_KSCrashReportWriter *writer) {
    CAUSE_MACH_EXCEPTION;
}

#define DEFINE_SCENARIO(NAME, CRASH, HANDLER) \
@interface NAME : Scenario \
@end \
@implementation NAME \
- (void)configure { \
    [super configure]; \
    self.config.onCrashHandler = HANDLER; \
} \
- (void)run { \
    CRASH; \
} \
\
@end

DEFINE_SCENARIO(RecrashCppMachScenario,      THROW_CPP_EXCEPTION,   OnCrashBadAccess)
DEFINE_SCENARIO(RecrashCppSignalScenario,    THROW_CPP_EXCEPTION,   OnCrashAbort)
DEFINE_SCENARIO(RecrashObjcMachScenario,     THROW_OBJC_EXCEPTION,  OnCrashBadAccess)
DEFINE_SCENARIO(RecrashObjcSignalScenario,   THROW_OBJC_EXCEPTION,  OnCrashAbort)
DEFINE_SCENARIO(RecrashMachMachScenario,     CAUSE_MACH_EXCEPTION,  OnCrashBadAccess)
DEFINE_SCENARIO(RecrashMachSignalScenario,   CAUSE_MACH_EXCEPTION,  OnCrashAbort)
DEFINE_SCENARIO(RecrashSignalMachScenario,   RAISE_SIGNAL,          OnCrashBadAccess)
DEFINE_SCENARIO(RecrashSignalSignalScenario, RAISE_SIGNAL,          OnCrashAbort)
