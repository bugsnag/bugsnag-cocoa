//
//  BSGAllEventsDiscardRule.m
//  Bugsnag
//
//  Created by Robert Bartoszewski on 19/09/2025.
//  Copyright © 2025 Bugsnag Inc. All rights reserved.
//

#import "BSGAllEventsDiscardRule.h"

@implementation BSGAllEventsDiscardRule

- (BOOL)shouldDiscardEvent:(__unused NSDictionary *)eventPayload {
    return YES;
}

@end
