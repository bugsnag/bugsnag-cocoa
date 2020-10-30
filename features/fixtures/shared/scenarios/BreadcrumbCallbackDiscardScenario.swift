//
//  BreadcrumbCallbackDiscardScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class BreadcrumbCallbackDiscardScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = []

        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.metadata["addedVal"] = true
            return crumb.message == "Hello World"
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb("Hello World", metadata: ["foo": "bar"], type: .manual)
        Bugsnag.leaveBreadcrumb(withMessage: "This breadcrumb will be discarded")
        let error = NSError(domain: "BreadcrumbCallbackDiscardScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
