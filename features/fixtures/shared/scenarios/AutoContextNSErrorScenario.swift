//
//  AutoContextNSErrorScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class AutoContextNSErrorScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AutoContextNSErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
