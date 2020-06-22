//
// Created by Robin Macharg on 18/05/2020.
// Copyright (c) 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class AppAndDeviceAttributesScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false
      super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}

/**
 * Override default values in config
 */
class AppAndDeviceAttributesScenarioConfigOverride: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        
        self.config.appType = "iLeet"
        self.config.bundleVersion = "12345"
        self.config.context = "myContext"
        self.config.releaseStage = "secondStage"
        
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenarioConfigOverride", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}

class AppAndDeviceAttributesScenarioCallbackOverride: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        
        self.config.addOnSendError { (event) -> Bool in
            event.app.type = "newAppType"
            event.app.releaseStage = "thirdStage"
            event.app.version = "999"
            event.device.manufacturer = "Nokia"
            event.device.modelNumber = "0898"
            
            return true
        }
        
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenarioCallbackOverride", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}


