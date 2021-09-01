//
//  CriticalThermalStateScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 19/08/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

@available(iOS 11.0, tvOS 11.0, *)
class CriticalThermalStateScenario: Scenario {
    
    override func run() {
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfoStub())
    }
    
    class ProcessInfoStub: NSObject {
        @objc let thermalState: ProcessInfo.ThermalState = .critical
    }
}
