//
//  OOMErrorTypesScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 13/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class OOMEnabledErrorTypesScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.enabledErrorTypes.ooms = false
        self.config.autoDetectErrors = true
        
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notify(NSException(name: NSExceptionName("OOMEnabledErrorTypesScenario"),
            reason: "OOMEnabledErrorTypesScenario",
            userInfo: nil))
    }
}
