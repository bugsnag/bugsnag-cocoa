//
//  ExtensionDelegate.swift
//  swift-watchos WatchKit Extension
//
//  Created by Karl Stenerud on 17.05.22.
//

import WatchKit
import Bugsnag
import BugsnagNetworkRequestPlugin

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        /**
         This is the minimum amount of setup required for Bugsnag to work.  Simply add your API key to the app's .plist (Supporting Files/Info.plist) and the application will deliver all error and session notifications to the appropriate dashboard.
         
         You can find your API key in your Bugsnag dashboard under the settings menu.
         */
        Bugsnag.start()

        /**
         Bugsnag behavior can be configured through the plist and/or further extended in code by creating a BugsnagConfiguration object and passing it to [Bugsnag startWithConfiguration].
         
         All subsequent setup is optional, and will configure your Bugsnag setup in different ways. A few common examples are included here, for more detailed explanations please look at the documented configuration options at https://docs.bugsnag.com/platforms/ios/configuration-options/
         */
        
        // Create config object from the application plist
//      let config = BugsnagConfiguration.loadConfig()
        // ... or construct an empty object
//      let config = BugsnagConfiguration("YOUR-API-KEY")

        /**
         This sets some user information that will be attached to each error.
         */
//        config.setUser("DefaultUser", withEmail:"Not@real.fake", andName:"Default User")

        /**
         The appVersion will let you see what release an error is present in.  This will be picked up automatically from your build settings, but can be manually overwritten as well.
         */
//        config.appVersion = "1.5.0"

        /**
         When persisting a user you won't need to set the user information everytime the app opens, instead it will be persisted between each app session.
         */
//        config.persistUser = true

        /**
         Enabled error types allow you to customize exactly what errors are automatically captured and delivered to your Bugsnag dashboard.  A detailed breakdown of each error type can be found in the configuration option documentation.
         */
//        config.enabledErrorTypes.unhandledExceptions = true

        /**
         To enable network breadcrumbs, add the BugsnagNetworkRequestPlugin plugin to your config.
         */
//        config.add(BugsnagNetworkRequestPlugin())

        /**
         If there's information that you do not wish sent to your Bugsnag dashboard, such as passwords or user information, you can set the keys as redacted. When a notification is sent to Bugsnag all keys matching your set filters will be redacted before they leave your application.
         All automatically captured data can be found here: https://docs.bugsnag.com/platforms/ios/automatically-captured-data/.
         */
//        config.redactedKeys = ["password", "credit_card_number"]

        /**
         Finally, start Bugsnag with the specified configuration:
         */
//        Bugsnag.start(with: config)
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

}
