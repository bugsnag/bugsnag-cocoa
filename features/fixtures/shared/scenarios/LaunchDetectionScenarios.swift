//
//  LaunchDetectionScenarios.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 04/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class LaunchDetectionHandledExceptionsScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.notify(NSException(name: .genericException, reason: "isLaunching should be true"))
        
        after(.seconds(6)) {
            Bugsnag.notify(NSException(name: .genericException, reason: "isLaunching should be false once `launchDurationMillis` has expired"))
        }
    }
}

// MARK: -

class ShortLaunchDurationScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.launchDurationMillis = 1000
        super.startBugsnag()
    }
    
    override func run() {
        after(.seconds(2)) {
            Bugsnag.notify(NSException(name: .genericException, reason: "isLaunching should be false once `launchDurationMillis` has expired"))
        }
    }
}

// MARK: -

class InfiniteLaunchDurationScenario: Scenario {
    
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

class UnhandledExceptionDuringLaunchScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        NSException(name: .genericException, reason: "isLaunching should be true").raise()
    }
}

// MARK: -

class UnhandledExceptionAfterLaunchScenario: Scenario {
    
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
