//
//  OnSendCallbackOrderScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Verifies that OnSend callbacks run in the order in which they were added
 */
class OnSendCallbackOrderScenario : Scenario {

    var callbackOrder = 0

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSendError { (event) -> Bool in
            event.addMetadata(self.callbackOrder, key: "config", section: "callbacks")
            self.callbackOrder += 1
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "OnSendCallbackOrderScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            event.addMetadata(self.callbackOrder, key: "notify", section: "callbacks")
            self.callbackOrder += 1
            return true
        }
    }
}
