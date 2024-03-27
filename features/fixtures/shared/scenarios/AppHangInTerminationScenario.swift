//
//  AppHangInTerminationScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 25/08/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class AppHangInTerminationScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.appHangThresholdMillis = 2_000
    }
    
    override func run() {
        #if os(iOS)
        let willTerminate = UIApplication.willTerminateNotification
        #elseif os(macOS)
        let willTerminate = NSApplication.willTerminateNotification
        #endif
        
        NotificationCenter.default.addObserver(forName: willTerminate, object: nil, queue: nil) {
            logDebug("Received \($0.name.rawValue), simulating an app hang...")
            Thread.sleep(forTimeInterval: 3)
        }
        
        #if os(iOS)
        // Appium is not able to close apps gracefully, so we simulate this using private API
        UIApplication.shared.perform(Selector(("terminateWithSuccess")))
        #elseif os(macOS)
        NSApp.terminate(self)
        #endif
    }
}
