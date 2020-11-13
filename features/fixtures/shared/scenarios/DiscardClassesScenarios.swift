//
//  DiscardClassesScenarios.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 11/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

extension NSExceptionName {
    
    /// An exception name that should not be discarded by the discardClasses values in these scenarios.
    static let notDiscarded = NSExceptionName("NotDiscarded")
}

// MARK: -

class DiscardClassesHandledExceptionRegexScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.discardClasses = try! [NSRegularExpression(pattern: #"NS\w+Exception"#)]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notify(NSException(name: .genericException, reason: "This exception should be discarded")) { _ in
            fatalError("OnError should not be called for discarded errors")
        }
        Bugsnag.notify(NSException(name: .notDiscarded, reason: "This exception should not be discarded"))
    }
}

// MARK: -

class DiscardClassesUnhandledExceptionScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.discardClasses = [NSExceptionName.rangeException.rawValue]
        config.addOnSendError {
            precondition(!$0.unhandled, "OnSendError should not be called for discarded errors (NSRangeException)")
            return true
        }
        super.startBugsnag()
        
        if Bugsnag.appDidCrashLastLaunch() {
            Bugsnag.notify(NSException(name: .notDiscarded, reason: "This exception should not be discarded"))
        }
    }
    
    override func run() {
        NSArray().object(at: 0)
    }
}

// MARK: -

class DiscardClassesUnhandledCrashScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.discardClasses = ["SIGABRT"]
        config.addOnSendError {
            precondition(!$0.unhandled, "OnSendError should not be called for discarded errors (SIGABRT)")
            return true
        }
        super.startBugsnag()
        
        if Bugsnag.appDidCrashLastLaunch() {
            Bugsnag.notify(NSException(name: .notDiscarded, reason: "This exception should not be discarded"))
        }
    }
    
    override func run() {
        abort()
    }
}
