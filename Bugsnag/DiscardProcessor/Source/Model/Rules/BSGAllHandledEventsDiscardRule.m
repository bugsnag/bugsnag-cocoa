//
//  BSGAllHandledEventsDiscardRule.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGAllHandledEventsDiscardRule.h"
#import "../../../../Helpers/BSGKeys.h"
#import "../../../../KSCrash/Source/KSCrash/Recording/Tools/BSG_KSLogger.h"

@implementation BSGAllHandledEventsDiscardRule

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    bsg_i_kslog_logCBasic("RULE: ALL_HANDLED");
    return [eventPayload[BSGKeyUnhandled] isEqual:@(NO)];
}

@end
