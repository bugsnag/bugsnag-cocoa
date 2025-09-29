//
//  BSGAllEventsDiscardRule.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGAllEventsDiscardRule.h"
#import "../../../../KSCrash/Source/KSCrash/Recording/Tools/BSG_KSLogger.h"

@implementation BSGAllEventsDiscardRule

- (BOOL)shouldDiscardEvent:(__unused NSDictionary *)eventPayload {
    bsg_i_kslog_logCBasic("RULE: ALL");
    return YES;
}

@end
