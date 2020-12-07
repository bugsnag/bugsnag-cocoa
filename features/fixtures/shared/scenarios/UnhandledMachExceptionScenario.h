//
//  UnhandledMachExceptionScenario.h
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MarkUnhandledHandledScenario.h"

NS_ASSUME_NONNULL_BEGIN

@interface UnhandledMachExceptionScenario : Scenario

@end

@interface UnhandledMachExceptionOverrideScenario : MarkUnhandledHandledScenario

@end

NS_ASSUME_NONNULL_END
