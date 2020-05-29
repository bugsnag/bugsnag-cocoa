//
//  SessionCallbackOverrideScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class SessionCallbackOverrideScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSession { (session) -> Bool in
            session.app.id = "customAppId"
            session.device.id = "customDeviceId"
            session.setUser("customUserId", withEmail: nil, andName: nil)
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}
