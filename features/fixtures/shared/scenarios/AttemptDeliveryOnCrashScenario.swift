//
//  AttemptDeliveryOnCrashScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 29/09/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

class AttemptDeliveryOnCrashScenario: Scenario {
    
    override func startBugsnag() {
        BSGCrashSentryDeliveryTimeout = 15
        config.attemptDeliveryOnCrash = true
        config.addOnSendError { event in
            event.context = "OnSendError"
            return true
        }
        super.startBugsnag()
    }
    
    override func run() {
        guard let eventMode = eventMode else { return } 
        switch eventMode {
        case "BadAccess":
            if let ptr = UnsafePointer<CChar>(bitPattern: 42) {
                strlen(ptr)
            }
            break
            
        case "NSException":
            NSArray().object(at: 42)
            break
            
        case "SwiftFatalError":
            _ = URL(string: "")!
            break
            
        default:
            break
        }
    }
}
