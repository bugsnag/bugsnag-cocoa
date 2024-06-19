//
//  OnSendErrorCallbackFeatureFlagsScenario.swift
//  iOSTestApp
//

import Foundation

class OnSendErrorCallbackFeatureFlagsScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.addOnSendError { (event) -> Bool in
            event.addFeatureFlag(name: "fromCallback", variant: event.featureFlags[0].variant)
            event.clearFeatureFlag(name: "deleteMe")
            return true
        }
    }

    override func run() {
        Bugsnag.addFeatureFlag(name: "fromStartup", variant: "a")
        Bugsnag.addFeatureFlag(name: "deleteMe")
        let error = NSError(domain: "OnSendErrorCallbackFeatureFlagsScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
