//
//  NotifyCallbackCrashScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 11/06/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class NotifyCallbackCrashScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "NotifyCallbackCrashScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { (event) -> Bool in
            event.addMetadata(true, key: "beforeCrash", section: "callbacks")

            // throw an exception to crash in the callback
            NSException(name: NSExceptionName("NotifyCallbackCrashScenario"),
                        reason: "Message: NotifyCallbackCrashScenario",
                        userInfo: nil).raise()

            event.addMetadata(true, key: "afterCrash", section: "callbacks")
            return true
        }
    }
}
