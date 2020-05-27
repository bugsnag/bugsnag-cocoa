//
//  OnSendOverwriteScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Verifies that an OnSend callback can overwrite information for an unhandled error
 */
class OnSendOverwriteScenario : Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSendError { (event) -> Bool in
            event.app.id = "customAppId"
            event.context = "customContext"
            event.device.id = "customDeviceId"
            event.groupingHash = "customGroupingHash"
            event.severity = .info
            event.setUser("customId", withEmail: "customEmail", andName: "customName")
            return true
        }
        super.startBugsnag()
    }

    override func run() {

    }
}
