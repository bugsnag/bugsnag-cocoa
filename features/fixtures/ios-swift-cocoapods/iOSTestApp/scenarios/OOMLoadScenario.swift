//
//  OOMLoadScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 13/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

class OOMLoadScenario: OOMBaseScenario {

    override func startBugsnag() {
        self.createOOMFiles()

        // Use a loaded config so OOMs are enabled by default
        config = BugsnagConfiguration.loadConfig()
        // We only want the one request
        config.autoTrackSessions = false
        Bugsnag.start(with: config)
    }

    override func run() {}
}
