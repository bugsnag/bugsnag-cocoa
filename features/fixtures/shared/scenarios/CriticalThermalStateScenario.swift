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
    
    override func run() {
        
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfoStub())
        after(.seconds(3)) {
            kill(getpid(), SIGKILL)
        }
    }

    class ProcessInfoStub: NSObject {
        @objc let thermalState: ProcessInfo.ThermalState = .critical
    }
}

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}