//
//  MetadataMergeScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class MetadataMergeScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        // set placeholder values
        Bugsnag.addMetadata("initialValue", key: "nonNullValue", section: "custom")
        Bugsnag.addMetadata("initialValue", key: "nullValue", section: "custom")
        Bugsnag.addMetadata("initialValue", key: "invalidValue", section: "custom")

        let error = NSError(domain: "MetadataMergeScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in

            // null values should remove existing values
            event.addMetadata("overriddenValue", key: "nonNullValue", section: "custom")

            // null values should remove existing values
            event.addMetadata(nil, key: "nullValue", section: "custom")

            // invalid values should be ignored
            event.addMetadata(Calendar.current, key: "invalidValue", section: "custom")
            return true
        }
    }
}
