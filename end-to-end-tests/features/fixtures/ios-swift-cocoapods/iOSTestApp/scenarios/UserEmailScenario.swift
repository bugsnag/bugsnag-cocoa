//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled error to Bugsnag, which only includes a user's email
 */
internal class UserEmailScenario: Scenario {
    override func startBugsnag() {
      self.config.shouldAutoCaptureSessions = false;
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.configuration()?.setUser(nil, withName: nil, andEmail: "user@example.com")
        let error = NSError(domain: "UserEmailScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
