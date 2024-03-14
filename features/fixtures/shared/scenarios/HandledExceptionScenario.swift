//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled Exception to Bugsnag
 */
class HandledExceptionScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        Bugsnag.notify(NSException(name: NSExceptionName("HandledExceptionScenario"),
                reason: "Message: HandledExceptionScenario",
                userInfo: nil))
    }

}
