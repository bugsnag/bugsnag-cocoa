//
//  MetadataRedactionNestedScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled Error to Bugsnag with some nested metadata that is redacted with custom keys
 */
class MetadataRedactionNestedScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      self.config.redactedKeys = ["name", "age"]
      super.startBugsnag()
    }

    override func run() {
        let dictionary = [
            "alpha": [
                "password": "foo",
                "name": "Bob"
            ],
            "beta": [
                "gamma": [
                    "password": "foo",
                    "age": "7",
                    "name": [
                        "title": "Mr"
                    ]
                ]
            ]
        ]
        Bugsnag.addOnSession { (block) -> Bool in
            return true;
        }
        Bugsnag.addMetadata(dictionary, section: "custom")

        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            let password = event.getMetadata(section: "custom", key: "password")
            event.addMetadata(password, key: "callbackValue", section: "extras")
            return true
        }
    }
}
