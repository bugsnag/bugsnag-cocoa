//
//  BreadcrumbCallbackCrashScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class BreadcrumbCallbackCrashScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = []

        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.metadata["addedInCallback"] = true

            // throw an exception to crash in the callback
            NSException(name: NSExceptionName("BreadcrumbCallbackCrashScenario"),
                        reason: "Message: BreadcrumbCallbackCrashScenario",
                        userInfo: nil).raise()

            crumb.metadata["shouldNotHappen"] = "it happened"
            return true
        }
        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.metadata["secondCallback"] = true
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb("Hello World", metadata: ["foo": "bar"], type: .manual)
        let error = NSError(domain: "BreadcrumbCallbackCrashScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
