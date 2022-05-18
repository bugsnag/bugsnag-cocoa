//
//  AppHangScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 05/03/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class AppHangScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = 2_000
        config.enabledBreadcrumbTypes = [.user]
        config.addFeatureFlag(name: "Testing")
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.setContext("App Hang Scenario")
        let timeInterval = TimeInterval(eventMode!)!
        NSLog("Simulating an app hang of \(timeInterval) seconds...")
        if timeInterval > 2 {
            Thread.sleep(forTimeInterval: 1.5)
            Bugsnag.leaveBreadcrumb(withMessage: "This breadcrumb was left during the hang, before detection")
            Thread.sleep(forTimeInterval: timeInterval - 1.5)
        } else {
            Thread.sleep(forTimeInterval: timeInterval)
        }
        Bugsnag.leaveBreadcrumb(withMessage: "This breadcrumb was left after the hang")
        NSLog("Finished sleeping")
    }
}
