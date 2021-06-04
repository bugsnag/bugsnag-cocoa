//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled error to Bugsnag, which includes user data.
 */
internal class UserEnabledScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.setUser("123", withEmail: "user@example.com", andName: "Joe Bloggs")
        let error = NSError(domain: "UserEnabledScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
