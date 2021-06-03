//
// Created by Robin Macharg on 18/05/2020.
// Copyright (c) 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled Error to Bugsnag
 */
class AppAndDeviceAttributesScenario: Scenario {

    override func startBugsnag() {
        config.autoTrackSessions = false
        config.launchDurationMillis = 1000
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
        after(.seconds(2)) {
            Bugsnag.notifyError(error)
        }
    }
}

// MARK: -

/**
 * Override default values in config
 */
class AppAndDeviceAttributesScenarioConfigOverride: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        
        self.config.appType = "iLeet"
        self.config.bundleVersion = "12345"
        self.config.context = "myContext"
        self.config.releaseStage = "secondStage"
        
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenarioConfigOverride", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}

// MARK: -

class AppAndDeviceAttributesScenarioCallbackOverride: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        
        self.config.addOnSendError { (event) -> Bool in
            event.app.type = "newAppType"
            event.app.releaseStage = "thirdStage"
            event.app.version = "999"
            event.app.bundleVersion = "42"
            event.device.manufacturer = "Nokia"
            event.device.modelNumber = "0898"
            
            return true
        }
        
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenarioCallbackOverride", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}

// MARK: -

class AppAndDeviceAttributesInfiniteLaunchDurationScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.launchDurationMillis = 0
        super.startBugsnag()
    }
    
    override func run() {
        after(.seconds(6)) {
            Bugsnag.notify(NSException(name: .genericException, reason: "isLaunching should be true if `launchDurationMillis` is 0"))
        }
    }
}

// MARK: -

class AppAndDeviceAttributesUnhandledExceptionDuringLaunchScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        NSException(name: .genericException, reason: "isLaunching should be true").raise()
    }
}

// MARK: -

class AppAndDeviceAttributesUnhandledExceptionAfterLaunchScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.markLaunchCompleted()
        NSException(name: .genericException, reason: "isLaunching should be false after `Bugsnag.markLaunchCompleted()`").raise()
    }
}

// MARK: -

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}
