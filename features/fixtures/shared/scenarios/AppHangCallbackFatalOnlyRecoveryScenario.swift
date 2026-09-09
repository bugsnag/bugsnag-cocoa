//
//  AppHangCallbackFatalOnlyRecoveryScenario.swift
//  iOSTestAppXcFramework
//
//  Created by Meiyalagan Ramadurai on 28/08/26.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

class AppHangCallbackFatalOnlyRecoveryScenario: Scenario {

    override func configure() {
        super.configure()
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        config.sendLaunchCrashesSynchronously = false

        config.appHangCallback = { event in
            event.addMetadata("captured-at-detection",
                              key: "callbackState",
                              section: "appHangCallback")
        }
    }

    override func run() {
        // Exceeds the fatal-only threshold, then the app recovers.
        Thread.sleep(forTimeInterval: 3)
    }
}

