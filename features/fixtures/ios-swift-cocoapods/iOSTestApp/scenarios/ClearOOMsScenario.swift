//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class ClearOOMsScenario: Scenario {
    
    override func startBugsnag() {
        self.config.reportOOMs = false
        self.config.shouldAutoCaptureSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        
    }
}
