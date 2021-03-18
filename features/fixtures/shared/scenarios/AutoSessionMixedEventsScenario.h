//
//  AutoSessionMixedEventsScenario.h
//  iOSTestApp
//
//  Created by Delisa on 7/16/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface AutoSessionMixedEventsScenario : Scenario

@property (copy, nonatomic) dispatch_block_t onEventDelivery;

@end
