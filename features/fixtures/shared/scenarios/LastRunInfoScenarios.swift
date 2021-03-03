//
//  LastRunInfoScenarios.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 11/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class LastRunInfoConsecutiveLaunchCrashesScenario: Scenario {
    
    override func startBugsnag() {
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
        super.startBugsnag()
    }
    
    override func run() {
        fatalError("Oh no, the app crashed!")
    }
}
