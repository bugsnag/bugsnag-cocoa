//
//  ReleaseStageSessionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

class EnabledReleaseStageAutoSessionScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        // session should be tracked automatically
    }
}
