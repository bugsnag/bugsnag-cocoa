//
//  OnErrorOverwriteUnhandledTrueScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Verifies that an OnErrorCallback can overwrite unhandled for a handled error
 */
class OnErrorOverwriteUnhandledTrueScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            event.app.id = "customAppId"
            event.context = "customContext"
            event.groupingDiscriminator = "customGroupingDiscriminator"
            event.device.id = "customDeviceId"
            event.groupingHash = "customGroupingHash"
            event.severity = .info
            event.setUser("customId", withEmail: "customEmail", andName: "customName")
            event.unhandled = true
            return true
        }
    }
}
