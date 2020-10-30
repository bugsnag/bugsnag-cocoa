//
//  UserDefaultInfoScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 19/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled error to Bugsnag which  includes the default user information
 */
internal class UserDefaultInfoScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "UserDefaultInfoScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
