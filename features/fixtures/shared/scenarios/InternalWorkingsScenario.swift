//
//  IsStartedScenario.swift
//  iOSTestApp
//
//  Created by Robert B on 03/03/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

@objc class InternalWorkingsScenario: Scenario {
    
    override func startBugsnag() {
        verifyBugsnagIsNotStarted()
        super.startBugsnag()
    }

    override func run() {
        verifyBugsnagIsStarted()
        reportStatusOk()
    }
    
    private func verifyBugsnagIsStarted() {
        assert(Bugsnag.isStarted(), "Bugsnag should be started")
    }
    
    private func verifyBugsnagIsNotStarted() {
        assert(!Bugsnag.isStarted(), "Bugsnag should not be started initially")
    }
    
    private func reportStatusOk() {
        Bugsnag.notify(NSException(name: NSExceptionName("InternalWorkingsScenario"),
                reason: "All Clear!",
                userInfo: nil))
    }
}
