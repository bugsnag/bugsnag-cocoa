//
//  SessionCallbackOrderScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class SessionCallbackOrderScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;

        var count = 0
        self.config.addOnSession { (session) -> Bool in
            session.app.id = "First callback: \(count)"
            count += 1
            return true
        }
        self.config.addOnSession { (session) -> Bool in
            session.device.id = "Second callback: \(count)"
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}
