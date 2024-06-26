//
//  ManualContextClientScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class ManualContextClientScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        Bugsnag.setContext("contextFromClient")
        let error = NSError(domain: "ManualContextClientScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
