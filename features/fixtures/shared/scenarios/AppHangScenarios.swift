//
//  AppHangScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 05/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

#if os(iOS)
import UIKit
#endif

class AppHangScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = 2_000
        config.enabledBreadcrumbTypes = [.user]
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.setContext("App Hang Scenario")
        let timeInterval = TimeInterval(eventMode!)!
        NSLog("Simulating an app hang of \(timeInterval) seconds...")
        if timeInterval > 2 {
            Thread.sleep(forTimeInterval: 1.5)
            Bugsnag.leaveBreadcrumb(withMessage: "This breadcrumb was left during the hang, before detection")
            Thread.sleep(forTimeInterval: timeInterval - 1.5)
        } else {
            Thread.sleep(forTimeInterval: timeInterval)
        }
        Bugsnag.leaveBreadcrumb(withMessage: "This breadcrumb was left after the hang")
        NSLog("Finished sleeping")
    }
}

class AppHangDefaultConfigScenario: Scenario {
    
    override func run() {
        let timeInterval: TimeInterval = 5
        NSLog("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        NSLog("Finished sleeping")
    }
}

class AppHangDisabledScenario: Scenario {

    override func startBugsnag() {
        config.enabledErrorTypes.appHangs = false
        super.startBugsnag()
    }
    
    override func run() {
        let timeInterval: TimeInterval = 5
        NSLog("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        NSLog("Finished sleeping")
    }
}

class AppHangFatalOnlyScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        // Sending synchronously causes an immediate retry upon failure, which creates flakes.
        config.sendLaunchCrashesSynchronously = false
        super.startBugsnag()
    }
    
    override func run() {
        NSLog("Hanging indefinitely...")
        while true {}
    }
}

class AppHangFatalDisabledScenario: Scenario {
    
    override func startBugsnag() {
        config.enabledErrorTypes.appHangs = false
        config.enabledErrorTypes.ooms = false
        super.startBugsnag()
    }
    
    override func run() {
        NSLog("Hanging indefinitely...")
        while true {}
    }
}

#if os(iOS)

class AppHangDidEnterBackgroundScenario: Scenario {
    
    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) {
            NSLog("Recevied \($0.name), now hanging indefinitely...")
            while true {}
        }
    }
}

class AppHangDidBecomeActiveScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = 2_000
        super.startBugsnag()
    }
    
    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) {
            NSLog("Recevied \($0.name), now sleeping for 3 seconds...")
            Thread.sleep(forTimeInterval: 3)
        }
    }
}

#endif
