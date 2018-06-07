//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//
#import <objc/runtime.h>

#import "Scenario.h"

@interface Bugsnag()
+ (id) notifier;
@end

@implementation Scenario

+ (Scenario *)createScenarioNamed:(NSString *)className
                       withConfig:(BugsnagConfiguration *)config {
    Class clz = NSClassFromString(className);

    if (clz == nil) { // swift class
        clz = NSClassFromString([NSString stringWithFormat:@"iOSTestApp.%@", className]);
    }

    NSAssert(clz != nil, @"Failed to find class named '%@'", className);

    BOOL implementsRun = method_getImplementation(class_getInstanceMethod([Scenario class], @selector(run))) !=
    method_getImplementation(class_getInstanceMethod(clz, @selector(run)));

    NSAssert(implementsRun, @"Class '%@' does not implement the run method", className);

    id obj = [clz alloc];

    NSAssert([obj isKindOfClass:[Scenario class]], @"Class '%@' is not a subclass of Scenario", className);

    return [(Scenario *)obj initWithConfig:config];
}

- (instancetype)initWithConfig:(BugsnagConfiguration *)config {
    if (self = [super init]) {
        self.config = config;
    }
    return self;
}

- (void)run {
}

- (void)startBugsnag {
    [Bugsnag startBugsnagWithConfiguration:self.config];
}

- (void)flushAllSessions {
    id notifier = [Bugsnag notifier];
    id sessionTracker = [notifier valueForKey:@"sessionTracker"];
    [sessionTracker performSelector:@selector(send)];
}

@end
