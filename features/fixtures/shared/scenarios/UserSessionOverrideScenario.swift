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

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        Bugsnag.setUser("abc", withEmail: nil, andName: nil)
        Bugsnag.addOnSession { (session) -> Bool in
            session.setUser("sessionCustomId", withEmail: "sessionCustomEmail", andName: "sessionCustomName")
            return true
        }
        Bugsnag.startSession()

        let error = NSError(domain: "UserIdScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            event.setUser("errorCustomId", withEmail: "errorCustomEmail", andName: "errorCustomName")
            return true
        }

    }
}
