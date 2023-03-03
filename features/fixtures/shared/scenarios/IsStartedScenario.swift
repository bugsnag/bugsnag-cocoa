//
//  IsStartedScenario.swift
//  iOSTestApp
//
//  Created by Robert B on 03/03/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

@objc class IsStartedScenario: Scenario {

    override func run() {
        assert(Bugsnag.isStarted(), "Bugsnag should be started")
    }
}
