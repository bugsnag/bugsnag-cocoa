//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class OOMDefaultScenario: OOMBaseScenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.releaseStage = "alpha"
        self.config.addOnSendError { (event) -> Bool in
            event.addMetadata(["shape": "line"], section: "extra")
            return true
        }
        self.config.bundleVersion = "1"
        self.config.appVersion = "1"
        self.config.enabledErrorTypes.ooms = true
        
        self.createOOMFiles()
        
        super.startBugsnag()
    }

    override func run() {}
}
