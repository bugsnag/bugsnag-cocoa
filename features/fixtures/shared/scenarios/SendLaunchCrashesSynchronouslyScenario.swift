//
//  SendLaunchCrashesSynchronouslyScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 15/02/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

class SendLaunchCrashesSynchronouslyScenario: Scenario {
    
    var startDuration: CFAbsoluteTime = 0
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.sendThreads = .never
        let startedAt = CFAbsoluteTimeGetCurrent()
        super.startBugsnag()
        startDuration = CFAbsoluteTimeGetCurrent() - startedAt
    }
    
    override func run() {
        if eventMode == "report" {
            NSLog(">>> Delaying to allow previous run's crash report to be sent")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [startDuration] in
                NSLog(">>> Calling notify() with startDuration = \(startDuration)")
                Bugsnag.notifyError(NSError(domain: "DummyError", code: 0)) {
                    $0.addMetadata(startDuration, key: "startDuration", section: "bugsnag")
                    return true
                }
            }
        } else {
            NSLog(">>> Calling fatalError()")
            fatalError()
        }
    }
}

class SendLaunchCrashesSynchronouslyFalseScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func startBugsnag() {
        config.sendLaunchCrashesSynchronously = false
        super.startBugsnag()
    }
}

class SendLaunchCrashesSynchronouslyLaunchCompletedScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func run() {
        if eventMode != "report" {
            NSLog(">>> Calling markLaunchCompleted()")
            Bugsnag.markLaunchCompleted()
        }
        super.run()
    }
}
