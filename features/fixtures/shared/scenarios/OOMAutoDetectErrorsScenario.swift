//
//  OOMAutoDetectErrorsScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 13/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class OOMAutoDetectErrorsScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.enabledErrorTypes.ooms = true
        self.config.autoDetectErrors = false
        
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notify(NSException(name: NSExceptionName("OOMAutoDetectErrorsScenario"),
            reason: "OOMAutoDetectErrorsScenario",
            userInfo: nil))
    }
}
