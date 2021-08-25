//
//  ThermalStateBreadcrumbScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 18/08/2021.
//  Copyright © 2021 Bugsnag Inc. All rights reserved.
//

@available(iOS 11.0, tvOS 11.0, *)
class ThermalStateBreadcrumbScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.enabledBreadcrumbTypes = [.state]
        
        super.startBugsnag()
    }
    
    override func run() {
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfoStub())
        
        Bugsnag.notifyError(NSError(domain: "DummyError", code: 0))
    }
    
    class ProcessInfoStub: NSObject {
        @objc let thermalState: ProcessInfo.ThermalState = .critical
    }
}
