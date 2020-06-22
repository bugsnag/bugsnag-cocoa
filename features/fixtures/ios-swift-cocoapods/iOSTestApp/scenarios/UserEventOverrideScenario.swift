//
//  UserEventOverrideScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled error to Bugsnag which overrides the user information in the event
 */
internal class UserEventOverrideScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.setUser("abc", withEmail: nil, andName: nil)
        let error = NSError(domain: "UserIdScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            event.setUser("customId", withEmail: "customEmail", andName: "customName")
            return true
        }
    }
}
