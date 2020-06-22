//
//  OriginalErrorNSErrorScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Verifies that the original error property is populated for a handled NSError
 */
class OriginalErrorNSErrorScenario : Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            let hasOriginalError = error.isEqual(event.originalError)
            event.addMetadata(hasOriginalError, key: "hasOriginalError", section: "custom")
            return true
        }
    }
}
