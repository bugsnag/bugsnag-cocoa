//
//  AutoDetectFalseHandledScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled error to Bugsnag with autoDetectErrors set to false
 */
internal class AutoDetectFalseHandledScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false
      self.config.autoDetectErrors = false
      super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "UserDefaultInfoScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
