//
//  AppHangScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 05/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class AppHangScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = 2_000
        super.startBugsnag()
    }
    
    override func run() {
        let timeInterval = TimeInterval(eventMode!)!
        NSLog("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
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
        super.startBugsnag()
    }
    
    override func run() {
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
        while true {}
    }
}
