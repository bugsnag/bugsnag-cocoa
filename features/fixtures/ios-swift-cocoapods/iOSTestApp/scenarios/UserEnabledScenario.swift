//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled error to Bugsnag, which includes user data.
 */
internal class UserEnabledScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.configuration()?.setUser("123", withName: "Joe Bloggs", andEmail: "user@example.com")
        let error = NSError(domain: "UserEnabledScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
