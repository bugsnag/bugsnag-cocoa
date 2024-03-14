//
//  AttemptDeliveryOnCrashScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 29/09/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

class AttemptDeliveryOnCrashScenario: Scenario {
    
    override func configure() {
        super.configure()
        BSGCrashSentryDeliveryTimeout = 15
        config.attemptDeliveryOnCrash = true
        config.addOnSendError { event in
            event.context = "OnSendError"
            return true
        }
    }
    
    override func run() {
        switch args[0] {
        case "BadAccess":
            if let ptr = UnsafePointer<CChar>(bitPattern: 42) {
                strlen(ptr)
            }
            break
            
        case "NSException":
            NSException(
                name: .rangeException,
                reason: "Something is out of range",
                userInfo: [
                    "date": Date(timeIntervalSinceReferenceDate: 0),
                    "scenario": "BareboneTestUnhandledErrorScenario",
                    NSUnderlyingErrorKey: NSError(domain: "ErrorDomain", code: 0)])
            .raise()
            break
            
        case "SwiftFatalError":
            _ = URL(string: "")!
            break
            
        default:
            break
        }
    }
}
