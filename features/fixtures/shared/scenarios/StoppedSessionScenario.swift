//
//  StoppedSessionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 19/02/2019.
//  Copyright © 2019 Bugsnag. All rights reserved.
//

import Foundation

internal class StoppedSessionScenario: Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        // send 1st exception which should include session info
        Bugsnag.startSession()
        Bugsnag.notifyError(NSError(domain: "First error", code: 101, userInfo: nil))

        // send 2nd exception which should not include session info
        Bugsnag.pauseSession()
        Bugsnag.notifyError(NSError(domain: "Second error", code: 101, userInfo: nil))
    }
}
