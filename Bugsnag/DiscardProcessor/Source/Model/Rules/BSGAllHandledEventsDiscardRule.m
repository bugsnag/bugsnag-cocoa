//
//  BSGAllHandledEventsDiscardRule.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGAllHandledEventsDiscardRule.h"
#import "../../../../Helpers/BSGKeys.h"

@implementation BSGAllHandledEventsDiscardRule

- (BOOL)shouldDiscardEvent:(NSDictionary *)eventPayload {
    return [eventPayload[BSGKeyUnhandled] isEqual:@(NO)];
}

@end
