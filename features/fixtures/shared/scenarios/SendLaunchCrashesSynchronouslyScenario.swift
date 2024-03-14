//
//  SendLaunchCrashesSynchronouslyScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 15/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class SendLaunchCrashesSynchronouslyScenario: Scenario {
    
    var startDuration: CFAbsoluteTime = 0
    
    override func configure() {
        super.configure()
        config.autoTrackSessions = false
        config.sendThreads = .never
    }

    override func startBugsnag() {
        let startedAt = CFAbsoluteTimeGetCurrent()
        super.startBugsnag()
        startDuration = CFAbsoluteTimeGetCurrent() - startedAt
    }
    
    override func run() {
        if args[0] == "report" {
            logDebug(">>> Delaying to allow previous run's crash report to be sent")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [startDuration] in
                NSLog(">>> Calling notify() with startDuration = \(startDuration)")
                Bugsnag.notifyError(NSError(domain: "DummyError", code: 0)) {
                    $0.addMetadata(startDuration, key: "startDuration", section: "bugsnag")
                    return true
                }
            }
        } else {
            logDebug(">>> Calling fatalError()")
            fatalError()
        }
    }
}
