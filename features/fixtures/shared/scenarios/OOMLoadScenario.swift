//
//  OOMLoadScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 13/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

class OOMLoadScenario: Scenario {

    override func startBugsnag() {
        config.autoTrackSessions = true
        config.enabledErrorTypes.ooms = true
        config.addMetadata(["bar": "foo"], section: "custom")
        config.setUser("foobar", withEmail: "foobar@example.com", andName: "Foo Bar")
        Bugsnag.start(with: config)
    }

    override func run() {
        Bugsnag.leaveBreadcrumb("OOMLoadScenarioBreadcrumb", metadata: ["foo":"bar"], type: BSGBreadcrumbType.manual)
        Bugsnag.notify(NSException(name: NSExceptionName("OOMLoadScenario"),
            reason: "OOMLoadScenario",
            userInfo: nil)
        )
    }
}
