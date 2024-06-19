//
//  CriticalThermalStateScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import Foundation

@available(iOS 11.0, tvOS 11.0, *)
class CriticalThermalStateScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.autoTrackSessions = false
    }

    override func run() {
        self.wait(forSessionDelivery: {
            Bugsnag.startSession()
        }, andThen: {
            let mockThermalState: @convention(block) () -> ProcessInfo.ThermalState = { .critical }

            method_setImplementation(
                class_getInstanceMethod(ProcessInfo.self, #selector(getter:ProcessInfo.thermalState))!,
                imp_implementationWithBlock(mockThermalState)
            )
            
            NotificationCenter.default.post(
                name: ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfo.processInfo)
            
            after(.seconds(3)) {
                kill(getpid(), SIGKILL)
            }
        })
    }
}

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}
