//
//  AppDurationScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 26/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

import Bugsnag

class AppDurationScenario: Scenario {
    
    var startDate: Date!
    var startTime: DispatchTime!
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.sendThreads = .never
        startDate = Date()
        startTime = .now()
        super.startBugsnag()
    }
    
    override func run() {
        DispatchQueue(label: "AppDurationScenario").async {
            // If the events are too close together, they will not be sent in the correct order.
            // This is because -[BugsnagFileStore allFilesByName] returns files in a random order.
            // The 1 second delay in -[BugsnagApiClient flushPendingData] means the spacing needs
            // to be quite large in order to get correct ordering of events.
            for delay in [0.0, 2.7, 5.5] {
                // DispatchQueue.asyncAfter was found to be too inaccurate for this scenario
                Thread.sleep(until: self.startDate.addingTimeInterval(delay))
                Bugsnag.notifyError(NSError(domain: "AppDurationScenario", code: Int(delay * 1000.0)))
            }
        }
    }
}
