//
//  ResumedSessionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 19/02/2019.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

internal class ResumedSessionScenario: Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        // send 1st exception
        Bugsnag.startSession()
        Bugsnag.notifyError(NSError(domain: "First error", code: 101, userInfo: nil))

        // send 2nd exception after resuming a session
        Bugsnag.pauseSession()
        Bugsnag.resumeSession()
        Bugsnag.notifyError(NSError(domain: "Second error", code: 101, userInfo: nil))
    }
}
