//
//  DiscardClassesHandledExceptionRegexScenario.swift
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
