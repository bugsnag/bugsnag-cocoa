//
//  UserSessionOverrideScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a session to Bugsnag which overrides the user information
 */
internal class UserSessionOverrideScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.setUser("abc", withEmail: nil, andName: nil)
        Bugsnag.addOnSession { (session) -> Bool in
            session.setUser("customId", withEmail: "customEmail", andName: "customName")
            return true
        }
        Bugsnag.startSession()
    }
}
