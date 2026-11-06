//
//  AppDelegate.m
//  TestHost-iOS
//
//  Created by Nick Dowell on 04/11/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

@end

API_AVAILABLE(ios(13.0))
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (strong, nonatomic) UIWindow *window;

@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions API_AVAILABLE(ios(13.0)) {
    (void)session;
    (void)connectionOptions;

    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
}

@end
