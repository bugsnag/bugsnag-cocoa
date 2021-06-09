//
// Created by Jamie Lynch on 23/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled error to Bugsnag, which only includes a user's id
 */
internal class UserIdScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.setUser("abc", withEmail: nil, andName: nil)
        let error = NSError(domain: "UserIdScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
