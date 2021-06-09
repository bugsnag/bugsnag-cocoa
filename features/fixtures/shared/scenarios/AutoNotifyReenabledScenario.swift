//
//  AutoNotifyReenabledScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 13/05/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

/**
 * Raises an unhandled NSException with autoNotify set to false then true,
 * which should be reported by Bugsnag
 */
internal class AutoNotifyReenabledScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.client.autoNotify = false
        Bugsnag.client.autoNotify = true
        NSException.init(name: NSExceptionName("SomeError"), reason: "Something went wrnog", userInfo: nil).raise()
    }
}
