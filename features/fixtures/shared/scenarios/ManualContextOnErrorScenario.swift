//
//  ManualContextOnErrorScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 28/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class ManualContextOnErrorScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSendError { (event) -> Bool in
            event.context = "OnErrorContext"
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "ManualContextOnErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
