//
//  OriginalErrorNSExceptionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Verifies that the original error property is populated for a handled NSException
 */
class OriginalErrorNSExceptionScenario : Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        let exc = NSException(name: NSExceptionName("HandledExceptionScenario"),
                            reason: "Message: HandledExceptionScenario",
                          userInfo: nil)

        Bugsnag.notify(exc) { (event) -> Bool in
            let hasOriginalError = exc.isEqual(event.originalError)
            event.addMetadata(hasOriginalError, key: "hasOriginalError", section: "custom")
            return true
        }
    }
}
