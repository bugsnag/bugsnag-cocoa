//
//  ThreadScenarios.h
//  iOSTestApp
//
//  Created by Jamie Lynch on 12/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Scenario.h"

@interface HandledErrorThreadSendAlwaysScenario : Scenario
@end

@interface UnhandledErrorThreadSendAlwaysScenario : Scenario
@end

@interface HandledErrorThreadSendUnhandledOnlyScenario : Scenario
@end

@interface UnhandledErrorThreadSendNeverScenario : Scenario
@end
