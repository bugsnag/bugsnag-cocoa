//
//  UserFromConfigSessionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a session to Bugsnag which contains a user set from Configuration
 */
internal class UserFromConfigSessionScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.setUser("abc", withEmail: "fake@gmail.com", andName: "Fay K")
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}

