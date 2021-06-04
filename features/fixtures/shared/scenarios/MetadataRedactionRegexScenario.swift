//
//  MetadataRedactionRegexScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled Error to Bugsnag with some sensitive metadata that is redacted with a regex
 */
class MetadataRedactionRegexScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      let regex = try! NSRegularExpression(pattern: "[a-z]at")
      self.config.redactedKeys = [regex]
      super.startBugsnag()
    }

    override func run() {
        Bugsnag.addMetadata("meow", key: "cat", section: "animals")
        Bugsnag.addMetadata("headwear", key: "hat", section: "clothes")
        Bugsnag.addMetadata("unknown", key: "9at", section: "debris")
        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
