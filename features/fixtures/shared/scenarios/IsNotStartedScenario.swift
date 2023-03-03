//
//  IsNotStartedScenario.swift
//  iOSTestApp
//
//  Created by Robert B on 03/03/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

@objc class IsNotStartedScenario: Scenario {

    override func startBugsnag() {
        assert(!Bugsnag.isStarted(), "Bugsnag should not be started initially")
        super.startBugsnag()
    }
    
    override func run() {}
}
