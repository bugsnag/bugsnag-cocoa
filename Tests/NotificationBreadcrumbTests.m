//
//  NotificationBreadcrumbTests.m
//  Bugsnag
//
//  Created by Nick Dowell on 10/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "BugsnagBreadcrumb+Private.h"
#import "BugsnagBreadcrumbs.h"
#import "BugsnagClient+Private.h"

#if TARGET_OS_IOS
#import "UIDeviceStub.h"
#endif


@interface NotificationBreadcrumbTests : XCTestCase

@property NSNotificationCenter *notificationCenter;
@property id notificationObject;
@property NSDictionary *notificationUserInfo;

@property BugsnagClient *client;

@property (nonatomic) BugsnagBreadcrumb *breadcrumb;

@end


#pragma mark -

@implementation NotificationBreadcrumbTests

#pragma mark Setup

- (void)setUp {
    self.breadcrumb = nil;
    BugsnagConfiguration *configuration = [[BugsnagConfiguration alloc] initWithApiKey:@"0192837465afbecd0192837465afbecd"];
    self.client = [[BugsnagClient alloc] initWithConfiguration:configuration];
    self.client.breadcrumbs = (id)self;
#if TARGET_OS_IOS
    self.client.uiDevice = (id)[[UIDeviceStub alloc] init];
    ((UIDeviceStub *)self.client.uiDevice).orientation = UIDeviceOrientationPortrait;
#endif
    [self.client start];
    self.notificationCenter = NSNotificationCenter.defaultCenter;
    self.notificationObject = nil;
    self.notificationUserInfo = nil;
}

- (BugsnagBreadcrumb *)breadcrumbForNotificationWithName:(NSString *)name {
    self.breadcrumb = nil;
    [self.notificationCenter postNotification:
     [NSNotification notificationWithName:name object:self.notificationObject userInfo:self.notificationUserInfo]];
    return self.breadcrumb;
}

#define TEST(__NAME__, __TYPE__, __MESSAGE__, __METADATA__) do { \
    BugsnagBreadcrumb *breadcrumb = [self breadcrumbForNotificationWithName:__NAME__]; \
    XCTAssertNotNil(breadcrumb); \
    if (breadcrumb) { \
        XCTAssertEqual(breadcrumb.type, __TYPE__); \
        XCTAssertEqualObjects(breadcrumb.message, __MESSAGE__); \
        XCTAssertEqualObjects(breadcrumb.metadata, __METADATA__); \
    } \
} while (0)

#pragma mark Tests

- (void)testStartedBreadcrumb {
    XCTAssertEqualObjects(self.breadcrumb.message, @"Bugsnag loaded");
}

#pragma mark iOS Tests

#if TARGET_OS_IOS

- (void)testUIApplicationNotifications {
    TEST(UIApplicationDidEnterBackgroundNotification, BSGBreadcrumbTypeState, @"App Did Enter Background", @{});
    TEST(UIApplicationDidReceiveMemoryWarningNotification, BSGBreadcrumbTypeState, @"Memory Warning", @{});
    TEST(UIApplicationUserDidTakeScreenshotNotification, BSGBreadcrumbTypeState, @"Took Screenshot", @{});
    TEST(UIApplicationWillEnterForegroundNotification, BSGBreadcrumbTypeState, @"App Will Enter Foreground", @{});
    TEST(UIApplicationWillTerminateNotification, BSGBreadcrumbTypeState, @"App Will Terminate", @{});
}
 
- (void)testUIDeviceNotifications {
    ((UIDeviceStub *)self.client.uiDevice).orientation = UIDeviceOrientationLandscapeLeft;
    TEST(UIDeviceOrientationDidChangeNotification, BSGBreadcrumbTypeState, @"Orientation Changed",
         (@{@"from": @"portrait", @"to": @"landscapeleft"}));
}

- (void)testUIKeyboardNotifications {
    TEST(UIKeyboardDidHideNotification, BSGBreadcrumbTypeState, @"Keyboard Became Hidden", @{});
    TEST(UIKeyboardDidShowNotification, BSGBreadcrumbTypeState, @"Keyboard Became Visible", @{});
}

- (void)testUIMenuNotifications {
    TEST(UIMenuControllerDidHideMenuNotification, BSGBreadcrumbTypeState, @"Did Hide Menu", @{});
    TEST(UIMenuControllerDidShowMenuNotification, BSGBreadcrumbTypeState, @"Did Show Menu", @{});
}

- (void)testUITextFieldNotifications {
    TEST(UITextFieldTextDidBeginEditingNotification, BSGBreadcrumbTypeUser, @"Began Editing Text", @{});
    TEST(UITextFieldTextDidEndEditingNotification, BSGBreadcrumbTypeUser, @"Stopped Editing Text", @{});
}

- (void)testUITextViewNotifications {
    TEST(UITextViewTextDidBeginEditingNotification, BSGBreadcrumbTypeUser, @"Began Editing Text", @{});
    TEST(UITextViewTextDidEndEditingNotification, BSGBreadcrumbTypeUser, @"Stopped Editing Text", @{});
}
 
- (void)testUIWindowNotifications {
    TEST(UIWindowDidBecomeHiddenNotification, BSGBreadcrumbTypeState, @"Window Became Hidden", @{});
    TEST(UIWindowDidBecomeVisibleNotification, BSGBreadcrumbTypeState, @"Window Became Visible", @{});
}

#endif

#pragma mark iOS & tvOS Tests

#if TARGET_OS_IOS || TARGET_OS_TV

// This should be on macOS too!
- (void)testNSUndoManagerNotifications {
    TEST(NSUndoManagerDidRedoChangeNotification, BSGBreadcrumbTypeState, @"Redo Operation", @{});
    TEST(NSUndoManagerDidUndoChangeNotification, BSGBreadcrumbTypeState, @"Undo Operation", @{});
}

- (void)testUITableViewNotifications {
    TEST(UITableViewSelectionDidChangeNotification, BSGBreadcrumbTypeNavigation, @"TableView Select Change", @{});
}

#endif

#pragma mark tvOS Tests

#if TARGET_OS_TV

- (void)testUIScreenNotifications {
    TEST(UIScreenBrightnessDidChangeNotification, BSGBreadcrumbTypeState, @"Screen Brightness Changed", @{});
}

- (void)testUIWindowNotifications {
    TEST(UIWindowDidBecomeHiddenNotification, BSGBreadcrumbTypeState, @"Window Became Hidden", @{});
    TEST(UIWindowDidBecomeKeyNotification, BSGBreadcrumbTypeState, @"Window Became Key", @{});
    TEST(UIWindowDidBecomeVisibleNotification, BSGBreadcrumbTypeState, @"Window Became Visible", @{});
    TEST(UIWindowDidResignKeyNotification, BSGBreadcrumbTypeState, @"Window Resigned Key", @{});
}

#endif

#pragma mark macOS Tests

#if TARGET_OS_OSX

- (void)testNSApplicationNotifications {
    TEST(NSApplicationDidBecomeActiveNotification, BSGBreadcrumbTypeState, @"App Became Active", @{});
    TEST(NSApplicationDidBecomeActiveNotification, BSGBreadcrumbTypeState, @"App Became Active", @{});
    TEST(NSApplicationDidHideNotification, BSGBreadcrumbTypeState, @"App Did Hide", @{});
    TEST(NSApplicationDidResignActiveNotification, BSGBreadcrumbTypeState, @"App Resigned Active", @{});
    TEST(NSApplicationDidUnhideNotification, BSGBreadcrumbTypeState, @"App Did Unhide", @{});
    TEST(NSApplicationWillTerminateNotification, BSGBreadcrumbTypeState, @"App Will Terminate", @{});
}

- (void)testNSControlNotifications {
    self.notificationObject = ({
        NSControl *control = [[NSControl alloc] init];
        control.accessibilityLabel = @"button1";
        control;
    });
    TEST(NSControlTextDidBeginEditingNotification, BSGBreadcrumbTypeUser, @"Control Text Began Edit", @{@"label": @"button1"});
    TEST(NSControlTextDidEndEditingNotification, BSGBreadcrumbTypeUser, @"Control Text Ended Edit", @{@"label": @"button1"});
}

- (void)testNSMenuNotifications {
    self.notificationUserInfo = @{@"MenuItem": [[NSMenuItem alloc] initWithTitle:@"menuAction:" action:nil keyEquivalent:@""]};
    TEST(NSMenuWillSendActionNotification, BSGBreadcrumbTypeState, @"Menu Will Send Action", @{@"action": @"menuAction:"});
}

- (void)testNSTableViewNotifications {
    self.notificationObject = [[NSTableView alloc] init];
    TEST(NSTableViewSelectionDidChangeNotification, BSGBreadcrumbTypeNavigation, @"TableView Select Change",
         (@{@"selectedColumn": @(-1), @"selectedRow": @(-1)}));
}

- (void)testNSWindowNotifications {
    TEST(NSWindowDidBecomeKeyNotification, BSGBreadcrumbTypeState, @"Window Became Key", @{});
    TEST(NSWindowDidEnterFullScreenNotification, BSGBreadcrumbTypeState, @"Window Entered Full Screen", @{});
    TEST(NSWindowDidExitFullScreenNotification, BSGBreadcrumbTypeState, @"Window Exited Full Screen", @{});
    TEST(NSWindowWillCloseNotification, BSGBreadcrumbTypeState, @"Window Will Close", @{});
    TEST(NSWindowWillMiniaturizeNotification, BSGBreadcrumbTypeState, @"Window Will Miniaturize", @{});
}

- (void)testNSWorkspaceNotifications {
    self.notificationCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    TEST(NSWorkspaceScreensDidSleepNotification, BSGBreadcrumbTypeState, @"Workspace Screen Slept", @{});
    TEST(NSWorkspaceScreensDidWakeNotification, BSGBreadcrumbTypeState, @"Workspace Screen Awoke", @{});
}

#endif

@end


#pragma mark -

@implementation NotificationBreadcrumbTests (BugsnagBreadcrumbsMock)

- (void)removeAllBreadcrumbs {}

- (void)addBreadcrumb:(NSString *)message {}

- (void)addBreadcrumbWithBlock:(BSGBreadcrumbConfiguration)block {
    self.breadcrumb = [BugsnagBreadcrumb breadcrumbWithBlock:block];
}

- (NSArray<BugsnagBreadcrumb *> *)breadcrumbs {
    return @[];
}

@end
