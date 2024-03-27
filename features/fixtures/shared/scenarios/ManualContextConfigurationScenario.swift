//
//  ManualContextConfigurationScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class ManualContextConfigurationScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.context = "contextFromConfig"
    }

    override func run() {
        let error = NSError(domain: "ManualContextConfigurationScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
