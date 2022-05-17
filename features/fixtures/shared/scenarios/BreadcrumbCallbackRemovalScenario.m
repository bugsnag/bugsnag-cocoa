//
//  BreadcrumbCallbackRemovalScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "Scenario.h"

@interface BreadcrumbCallbackRemovalScenario : Scenario
@end

@implementation BreadcrumbCallbackRemovalScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    self.config.enabledBreadcrumbTypes = BSGEnabledBreadcrumbTypeUser;

    [self.config addOnBreadcrumbBlock:^BOOL(BugsnagBreadcrumb * _Nonnull breadcrumb) {
        NSMutableDictionary *dict = [breadcrumb.metadata mutableCopy];
        dict[@"firstCallback"] = @"Whoops";
        breadcrumb.metadata = dict;
        return true;
    }];

    id block = ^BOOL(BugsnagBreadcrumb * _Nonnull breadcrumb) {
        breadcrumb.message = @"Feliz Navidad";
        return true;
    };
    BugsnagOnBreadcrumbRef onBreadcrumb = [self.config addOnBreadcrumbBlock:block];
    [self.config removeOnBreadcrumb:onBreadcrumb];

    [super startBugsnag];
}

- (void)run {
    [Bugsnag leaveBreadcrumbWithMessage:@"Hello World"
                               metadata:@{@"foo": @"bar"}
                                andType:BSGBreadcrumbTypeManual];
    NSError *error = [NSError errorWithDomain:@"BreadcrumbCallbackRemovalScenario" code:100 userInfo:nil];
    [Bugsnag notifyError:error];
}

@end
