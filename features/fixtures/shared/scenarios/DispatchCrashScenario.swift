//
//  DispatchCrashScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 17/12/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

class DispatchCrashScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }
    
    override func run() {
        precondition(Thread.isMainThread)
        DispatchQueue.main.sync {
            print("This code will never run because DispatchQueue.main.sync was called on the main thread")
        }
    }
}
