//
//  MetadataRedactionDefaultScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled Error to Bugsnag with some sensitive metadata that is redacted by default
 */
class MetadataRedactionDefaultScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.addMetadata("hunter2", key: "password", section: "custom")
        Bugsnag.addMetadata("hunter3", key: "Password", section: "custom")
        Bugsnag.addMetadata("not redacted", key: "password2", section: "custom")
        Bugsnag.addMetadata("brown fox", key: "normalKey", section: "custom")

        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            let password = event.getMetadata(section: "custom", key: "password")
            event.addMetadata(password, key: "callbackValue", section: "extras")
            return true
        }
    }
}
