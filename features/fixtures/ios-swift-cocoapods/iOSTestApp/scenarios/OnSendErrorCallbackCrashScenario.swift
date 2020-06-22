//
//  OnSendErrorCallbackCrashScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 11/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class OnSendErrorCallbackCrashScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.addOnSendError { (event) -> Bool in
            event.addMetadata(true, key: "beforeCrash", section: "callbacks")

            // throw an exception to crash in the callback
            NSException(name: NSExceptionName("OnSendErrorCallbackCrashScenario"),
                        reason: "Message: OnSendErrorCallbackCrashScenario",
                        userInfo: nil).raise()

            event.addMetadata(true, key: "afterCrash", section: "callbacks")
            return true
        }
        self.config.addOnSendError { (event) -> Bool in
            event.addMetadata(true, key: "secondCallback", section: "callbacks")
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "OnSendErrorCallbackCrashScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
