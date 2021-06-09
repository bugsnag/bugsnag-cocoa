//
//  OOMSessionScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 13/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class OOMSessionScenario: Scenario {

    override func startBugsnag() {
        config.enabledErrorTypes.ooms = true
        config.autoTrackSessions = false
        Bugsnag.start(with: config)
    }

    override func run() {
        Bugsnag.startSession()
    }
}
