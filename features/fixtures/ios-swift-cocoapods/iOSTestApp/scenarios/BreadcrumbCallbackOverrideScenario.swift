//
//  BreadcrumbCallbackOverrideScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 27/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class BreadcrumbCallbackOverrideScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = .log

        self.config.addOnBreadcrumb { (crumb) -> Bool in
            crumb.message = "Feliz Navidad"
            crumb.type = .manual
            crumb.metadata["foo"] = "wham"
            return true
        }
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb("Hello World", metadata: ["foo": "bar"], type: .log)
        let error = NSError(domain: "BreadcrumbCallbackOverrideScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
