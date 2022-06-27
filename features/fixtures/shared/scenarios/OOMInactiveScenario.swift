//
//  OOMInactiveScenario.swift
//  iOSTestApp
//
//  Created by Nick Dowell on 27/06/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#if os(iOS)

import UIKit

class OOMInactiveScenario: Scenario {
    
    override func startBugsnag() {
        config.enabledErrorTypes.ooms = true
        Bugsnag.start(with: config)
    }
    
    override func run() {
        // FIXME: Would be better if we could trigger a real transition to UIApplicationStateInactive
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification,
                                        object: UIApplication.shared, userInfo: nil)
        
        NSLog("Killing app to fake an OOM")
        kill(getpid(), SIGKILL)
    }
}

#endif
