//
// Created by Robin Macharg on 18/05/2020.
// Copyright (c) 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class AppAndDeviceAttributesScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
