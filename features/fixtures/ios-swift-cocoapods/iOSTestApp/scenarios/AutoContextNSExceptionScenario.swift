//
//  AutoContextNSExceptionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class AutoContextNSExceptionScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notify(NSException(name: NSExceptionName("AutoContextNSExceptionScenario"),
                                   reason: "Message: AutoContextNSExceptionScenario",
                                   userInfo: nil))
    }
}
