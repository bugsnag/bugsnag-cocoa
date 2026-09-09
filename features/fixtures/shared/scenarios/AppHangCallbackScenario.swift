//
//  AppHangCallbackScenario.swift
//  iOSTestAppXcFramework
//
//  Created by Meiyalagan Ramadurai on 28/08/26.
//  Copyright © 2026 Bugsnag. All rights reserved.
//

class AppHangCallbackScenario: Scenario {

    override func configure() {
        super.configure()
        config.appHangThresholdMillis = 2_000
        config.enabledBreadcrumbTypes = [.user]
        config.addFeatureFlag(name: "Testing")

        config.appHangCallback = { event in
            event.addMetadata("captured-at-detection",
                              key: "callbackState",
                              section: "appHangCallback")
        }
    }

    override func run() {
        Bugsnag.setContext("App Hang Callback Scenario")
        Bugsnag.setGroupingDiscriminator(
            "AppHangCallbackScenarioGroupingDiscriminator"
        )

        let timeInterval = TimeInterval(args[0])!
        logDebug("Simulating an app hang of \(timeInterval) seconds...")

        if timeInterval > 2 {
            Thread.sleep(forTimeInterval: 1.5)
            Bugsnag.leaveBreadcrumb(
                withMessage: "This breadcrumb was left during the hang, before detection"
            )
            Thread.sleep(forTimeInterval: timeInterval - 1.5)
        } else {
            Thread.sleep(forTimeInterval: timeInterval)
        }

        Bugsnag.leaveBreadcrumb(
            withMessage: "This breadcrumb was left after the hang"
        )
        logDebug("Finished sleeping")
    }
}
