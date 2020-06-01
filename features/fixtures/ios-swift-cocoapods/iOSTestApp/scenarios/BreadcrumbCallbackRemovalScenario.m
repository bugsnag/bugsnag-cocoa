//
//  BreadcrumbCallbackRemovalScenario.m
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import "BreadcrumbCallbackRemovalScenario.h"

@implementation BreadcrumbCallbackRemovalScenario

- (void)startBugsnag {
    self.config.autoTrackSessions = false;
    self.config.enabledBreadcrumbTypes = BSGBreadcrumbTypeManual;

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
    [self.config addOnBreadcrumbBlock:block];
    [self.config removeOnBreadcrumbBlock:block];

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
