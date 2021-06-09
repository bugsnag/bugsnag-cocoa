//
//  ReleaseStageSessionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

internal class EnabledReleaseStageAutoSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        // session should be tracked automatically
    }
}

internal class DisabledReleaseStageAutoSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        // session should be tracked automatically
    }
}


internal class EnabledReleaseStageManualSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}

internal class DisabledReleaseStageManualSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}
