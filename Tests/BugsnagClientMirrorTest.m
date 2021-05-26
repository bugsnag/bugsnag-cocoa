//
//  BugsnagClientMirrorTest.m
//  Tests
//
//  Created by Jamie Lynch on 30/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <Bugsnag/Bugsnag.h>

@interface BugsnagClientMirrorTest : XCTestCase
@property NSSet *clientMethodsNotRequiredOnBugsnag;
@property NSSet *bugsnagMethodsNotRequiredOnClient;
@end

/**
 * Verifies that methods on the Bugsnag and BugsnagClient class remain in sync.
 *
 * This class relies on introspection using the Objective-C runtime which gets the name
 * of all methods implemented in each class. As Objective-C doesn't seem to have a way of
 * only gathering methods implemented in a header file, the "not required" lists need to be
 * updated whenever a method signature changes within the Bugsnag/BugsnagClient class.
 */
@implementation BugsnagClientMirrorTest

- (void)setUp {
    // the following methods are implemented on BugsnagClient but do not need to
    // be mirrored on the Bugsnag facade
    self.clientMethodsNotRequiredOnBugsnag = [NSSet setWithArray:@[
            @"notify:handledState:block: v40@0:8@16@24@?32",
            @"setAppDidCrashLastLaunch: v20@0:8B16",
            @"started B16@0:8",
            @"start v16@0:8",
            @"initWithConfiguration: @24@0:8@16",
            @"watchLifecycleEvents: v24@0:8@16",
            @"setupConnectivityListener v16@0:8",
            @"setSessionTracker: v24@0:8@16",
            @"addTerminationObserver: v24@0:8@16",
            @"setLastOrientation: v24@0:8@16",
            @"oomWatchdog @16@0:8",
            @"initializeNotificationNameMap v16@0:8",
            @"willEnterBackground: v24@0:8@16",
            @"willEnterForeground: v24@0:8@16",
            @"setConfiguration: v24@0:8@16",
            @"orientationChanged: v24@0:8@16",
            @"setMetadataLock: v24@0:8@16",
            @"sendBreadcrumbForMenuItemNotification: v24@0:8@16",
            @"setState: v24@0:8@16",
            @"setOomWatchdog: v24@0:8@16",
            @"automaticBreadcrumbControlEvents @16@0:8",
            @"crashSentry @16@0:8",
            @"computeDidCrashLastLaunch v16@0:8",
            @"notifier @16@0:8",
            @"updateAutomaticBreadcrumbDetectionSettings v16@0:8",
            @"automaticBreadcrumbStateEvents @16@0:8",
            @"sessionTracker @16@0:8",
            @"addAutoBreadcrumbOfType:withMessage:andMetadata: v40@0:8Q16@24@32",
            @"automaticBreadcrumbTableItemEvents @16@0:8",
            @"updateCrashDetectionSettings v16@0:8",
            @"sendBreadcrumbForControlNotification: v24@0:8@16",
            @"dealloc v16@0:8",
            @"lastOrientation @16@0:8",
            @"setCrashSentry: v24@0:8@16",
            @"state @16@0:8",
            @"sendBreadcrumbForTableViewNotification: v24@0:8@16",
            @"pluginClient @16@0:8",
            @"setNotifier: v24@0:8@16",
            @"metadataChanged: v24@0:8@16",
            @"automaticBreadcrumbMenuItemEvents @16@0:8",
            @"serializeBreadcrumbs v16@0:8",
            @"addBreadcrumbWithBlock: v24@0:8@?16",
            @"unsubscribeFromNotifications: v24@0:8@16",
            @"setPluginClient: v24@0:8@16",
            @"lowMemoryWarning: v24@0:8@16",
            @"setAppCrashedLastLaunch: v20@0:8B16",
            @".cxx_destruct v16@0:8",
            @"startListeningForStateChangeNotification: v24@0:8@16",
            @"sendBreadcrumbForNotification: v24@0:8@16",
            @"batteryChanged: v24@0:8@16",
            @"started c16@0:8",
            @"setAppDidCrashLastLaunch: v20@0:8c16",
            @"setMetadata: v24@0:8@16",
            @"metadata @16@0:8",
            @"workspaceBreadcrumbStateEvents @16@0:8",
            @"startListeningForWorkspaceStateChangeNotifications: v24@0:8@16",
            @"codeBundleId @16@0:8",
            @"setCodeBundleId: v24@0:8@16",
            @"context @16@0:8",
            @"collectAppWithState @16@0:8",
            @"collectBreadcrumbs @16@0:8",
            @"collectThreads: @20@0:8B16",
            @"collectThreads: @20@0:8c16",
            @"collectDeviceWithState @16@0:8",
            @"extraRuntimeInfo @16@0:8",
            @"setExtraRuntimeInfo: v24@0:8@16",
            @"collectDeviceWithState @16@0:8",
            @"setStateEventBlocks: v24@0:8@16",
            @"addObserverWithBlock: v24@0:8@?16",
            @"removeObserverWithBlock: v24@0:8@?16",
            @"notifyObservers: v24@0:8@16",
            @"stateEventBlocks @16@0:8",
            @"generateDeviceWithState: @24@0:8@16",
            @"populateEventData: v24@0:8@16",
            @"generateAppWithState: @24@0:8@16",
            @"generateThreads @16@0:8",
            @"deserializeJson: @24@0:8*16",
            @"generateErrors: @24@0:8@16",
            @"generateError:threads: @32@0:8@16@24",
            @"appendNSErrorInfo:block:event: B40@0:8@16@?24@32",
            @"appendNSErrorInfo:block:event: c40@0:8@16@?24@32",
            @"createNSErrorWrapper: @24@0:8@16",
            @"setBreadcrumbs: v24@0:8@16",
            @"breadcrumbs @16@0:8",
            @"setUser: v24@0:8@16",
            @"didLikelyOOM B16@0:8",
            @"didLikelyOOM c16@0:8",
            @"shouldReportOOM B16@0:8",
            @"shouldReportOOM c16@0:8",
            @"systemState @16@0:8",
            @"setSystemState: v24@0:8@16",
            @"addAutoBreadcrumbForEvent: v24@0:8@16",
            @"appHangDetectedWithThreads: v24@0:8@16",
            @"appHangDetector @16@0:8",
            @"appHangEnded v16@0:8",
            @"appHangEvent @16@0:8",
            @"appLaunchTimer @16@0:8",
            @"appLaunchTimerFired: v24@0:8@16",
            @"configMetadataFile @16@0:8",
            @"configMetadataFromLastLaunch @16@0:8",
            @"eventFromLastLaunch @16@0:8",
            @"eventUploader @16@0:8",
            @"generateOutOfMemoryEvent @16@0:8",
            @"leaveBreadcrumbForEvent: v24@0:8@16",
            @"loadFatalAppHangEvent @16@0:8",
            @"metadataFile @16@0:8",
            @"metadataFromLastLaunch @16@0:8",
            @"notificationBreadcrumbs @16@0:8",
            @"sendLaunchCrashSynchronously v16@0:8",
            @"setAppHangDetector: v24@0:8@16",
            @"setAppHangEvent: v24@0:8@16",
            @"setAppLaunchTimer: v24@0:8@16",
            @"setConfigMetadataFromLastLaunch: v24@0:8@16",
            @"setEventFromLastLaunch: v24@0:8@16",
            @"setEventUploader: v24@0:8@16",
            @"setLastRunInfo: v24@0:8@16",
            @"setMetadataFromLastLaunch: v24@0:8@16",
            @"setNotificationBreadcrumbs: v24@0:8@16",
            @"setStarted: v20@0:8B16",
            @"setStarted: v20@0:8c16",
            @"setStateMetadataFromLastLaunch: v24@0:8@16",
            @"startAppHangDetector v16@0:8",
            @"stateMetadataFile @16@0:8",
            @"stateMetadataFromLastLaunch @16@0:8",
            @"autoNotify B16@0:8",
            @"autoNotify c16@0:8",
            @"setAutoNotify: v20@0:8B16",
            @"setAutoNotify: v20@0:8c16"
    ]];

    // the following methods are implemented on Bugsnag but do not need to
    // be mirrored on BugsnagClient
    self.bugsnagMethodsNotRequiredOnClient = [NSSet setWithArray:@[
            @"startWithApiKey: @24@0:8@16",
            @"startWithConfiguration: @24@0:8@16",
            @"updateCodeBundleId: v24@0:8@16",
            @"instance @16@0:8",
            @"client @16@0:8",
            @"bugsnagStarted B16@0:8",
            @"bugsnagStarted c16@0:8",
            @"leaveBreadcrumbWithBlock: v24@0:8@?16",
            @"getContext @16@0:8",
            @"start @16@0:8",
            @"purge v16@0:8"
    ]];
}

- (void)testBugsnagHasClientMethods {
    NSMutableSet *bugsnagMethods = [self methodNamesForClass:object_getClass([Bugsnag class])];
    NSMutableSet *clientMethods = [self methodNamesForClass:[BugsnagClient class]];

    // remove all methods implemented on Bugsnag from Client.
    // any leftover methods have not been implemented on the Bugsnag facade.
    [clientMethods minusSet:bugsnagMethods];
    [clientMethods minusSet:self.clientMethodsNotRequiredOnBugsnag];

    for (NSString *method in clientMethods) {
        XCTFail(@"The \"Bugsnag\" class should implement +%@", method);
    }
}

- (void)testClientHasBugsnagMethods {
    NSMutableSet *bugsnagMethods = [self methodNamesForClass:object_getClass([Bugsnag class])];
    NSMutableSet *clientMethods = [self methodNamesForClass:[BugsnagClient class]];

    // remove all methods implemented on Client from Bugsnag.
    // any leftover methods have not been implemented on the Client object.
    [bugsnagMethods minusSet:clientMethods];
    [bugsnagMethods minusSet:self.bugsnagMethodsNotRequiredOnClient];

    for (NSString *method in bugsnagMethods) {
        XCTFail(@"The \"BugsnagClient\" class should implement -%@", method);
    }
}

- (NSMutableSet<NSString *> *)methodNamesForClass:(Class)clz {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(clz, &count);
    NSMutableArray *data = [NSMutableArray new];

    for (unsigned int k = 0; k < count; k++) {
        Method method = methods[k];

        const char *name = sel_getName(method_getName(method));
        const char *encoding = method_getTypeEncoding(method);
        [data addObject:[NSString stringWithFormat:@"%s %s", name, encoding]];
    }
    free(methods);
    return [NSMutableSet setWithArray:data];
}

@end
