//
//  SessionCallbackDiscardScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class SessionCallbackDiscardScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;

        var count = 0
        self.config.addOnSession { (session) -> Bool in
            // discard anything other than the first request
            count += 1
            return count == 1
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
        Bugsnag.startSession()
        Bugsnag.startSession()
    }
}
