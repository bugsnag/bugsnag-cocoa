//
//  EnabledErrorTypesScenario.h
//  iOSTestApp
//
//  Created by Robin Macharg on 27/02/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"

NS_ASSUME_NONNULL_BEGIN

@interface DisableAllExceptManualExceptionsAndCrashScenario : Scenario
@end

@interface DisableAllExceptManualExceptionsSendManualAndCrashScenario : Scenario
@end

@interface DisableCPPExceptionScenario : Scenario
@end

@interface DisableNSExceptionScenario : Scenario
@end

@interface DisableMachExceptionScenario : Scenario
@end

@interface DisableSignalsExceptionScenario : Scenario
@end

NS_ASSUME_NONNULL_END
