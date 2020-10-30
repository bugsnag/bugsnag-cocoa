//
//  BreadcrumbCallbackOrderScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class BreadcrumbCallbackOrderScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = []

        var count = 0
        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.metadata["firstCallback"] = count
            count += 1
            return true
        }

        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.metadata["secondCallback"] = count
            count += 1
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb(withMessage: "Hello World")
        let error = NSError(domain: "BreadcrumbCallbackOrderScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
