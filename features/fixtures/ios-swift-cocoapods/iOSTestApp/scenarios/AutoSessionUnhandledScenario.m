//
//  AutoSessionUnhandledScenario.m
//  iOSTestApp
//
//  Created by Delisa on 7/13/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

#import "AutoSessionUnhandledScenario.h"

@implementation AutoSessionUnhandledScenario

- (void)run {
    NSException *ex = [NSException exceptionWithName:@"Kaboom" reason:@"The connection exploded" userInfo:nil];
    
    @throw ex;
}

@end
