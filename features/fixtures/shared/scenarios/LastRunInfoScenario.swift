//
//  LastRunInfoScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 11/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class LastRunInfoScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.launchDurationMillis = 0
        config.sendLaunchCrashesSynchronously = false
        config.addOnSendError {
            if let lastRunInfo = Bugsnag.lastRunInfo {
                $0.addMetadata(
                    ["consecutiveLaunchCrashes": lastRunInfo.consecutiveLaunchCrashes,
                     "crashed": lastRunInfo.crashed,
                     "crashedDuringLaunch": lastRunInfo.crashedDuringLaunch
                    ], section: "lastRunInfo")
            }
            return true
        }
    }
    
    override func run() {
        // Ensure we don't crash the fixture while the previous run's launch crash is being sent.
        // Don't rely on synchronous launch crash sending because that will only wait up to 2
        // seconds, and delivery occasionally takes longer than that on BrowserStack devices.
        waitForDelivery();
        
        if Bugsnag.lastRunInfo?.consecutiveLaunchCrashes == 3 {
            Bugsnag.markLaunchCompleted()
        }
        
        fatalError("Oh no, the app crashed!")
    }
    
    func waitForDelivery() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bugsnag.Bugsnag")
            .appendingPathComponent(Bundle.main.bundleIdentifier!)
            .appendingPathComponent("v1")
            .appendingPathComponent("KSCrashReports")
        
        while try! !FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])
                .filter({ $0.lastPathComponent.hasPrefix("CrashReport-") }).isEmpty {
            logDebug("LastRunInfoScenario: waiting for delivery of crash reports...")
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
