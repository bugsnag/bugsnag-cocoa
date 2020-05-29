//
//  SessionCallbackCrashScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class SessionCallbackCrashScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSession { (session) -> Bool in
            session.app.id = "someAppId"
            session.setUser("placeholderId", withEmail: nil, andName: nil)

            // crash the callback, subsequent modifications don't take place
            NSException(name: NSExceptionName("HandledExceptionScenario"),
            reason: "Message: HandledExceptionScenario",
                userInfo: nil).raise()

            session.setUser("Jimmy", withEmail: nil, andName: nil)
            return true
        }

        // overwrite app ID set in first callback
        self.config.addOnSession { (session) -> Bool in
            session.app.id = "customAppId"
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}
