//
//  AutoNotifyFalseHandledScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 13/05/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

/**
 * Sends a handled error to Bugsnag with autoNotify set to false
 */
internal class AutoNotifyFalseHandledScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.client.autoNotify = false
        let error = NSError(domain: "UserDefaultInfoScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
