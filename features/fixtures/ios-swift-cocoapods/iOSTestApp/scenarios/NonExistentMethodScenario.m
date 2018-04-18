//
// Created by Jamie Lynch on 12/04/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

#import "NonExistentMethodScenario.h"


@implementation NonExistentMethodScenario

- (void)run {
    [self performSelector:NSSelectorFromString(@"santaclaus:")];
}


@end
