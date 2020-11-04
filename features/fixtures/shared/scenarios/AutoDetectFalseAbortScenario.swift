//
//  AutoDetectFalseAbortScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
* Raises a SIGABRT with autoDetectErrors set to false, which should be ignored by Bugsnag
*/
internal class AutoDetectFalseAbortScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false
      self.config.autoDetectErrors = false
      super.startBugsnag()
    }

    override func run() {
        abort()
    }
}
