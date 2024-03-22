//
//  DelayedNotifyErrorScenario.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 22.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation

class DelayedNotifyErrorScenario: Scenario {
    
    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }
    
    @objc func notify_error() {
        let error = NSError(domain: "DelayedNotifyErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
