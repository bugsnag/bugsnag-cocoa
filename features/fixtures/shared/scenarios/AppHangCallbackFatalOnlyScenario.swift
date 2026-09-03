//
//  AppHangCallbackFatalOnlyScenario.swift
//  iOSTestAppXcFramework
//
//  Created by Meiyalagan Ramadurai on 28/08/26.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

class AppHangCallbackFatalOnlyScenario: Scenario {

    override func configure() {
        super.configure()
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        config.sendLaunchCrashesSynchronously = false
        config.addFeatureFlag(name: "Testing")

        config.appHangCallback = { event in
            event.addMetadata("captured-at-detection",
                              key: "callbackState",
                              section: "appHangCallback")
        }
    }

    override func run() {
        // Maze kills and relaunches the app after 10 seconds.
        Thread.sleep(forTimeInterval: 500)
    }
}
