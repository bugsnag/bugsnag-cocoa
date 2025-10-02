//
//  DelayedNotifyErrorScenario.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 22.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation
import UIKit

class DelayedNotifyErrorScenario: Scenario {
    
    private var shouldNotifyOnForeground = false
    
    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc func notify_error() {
        notify()
    }
    
    @objc func notify_error_on_foreground() {
        shouldNotifyOnForeground = true
    }
    
    @objc func willEnterForeground() {
        if (shouldNotifyOnForeground) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.notify()
            }
            shouldNotifyOnForeground = false
        }
    }
    
    func notify() {
        let error = NSError(domain: "DelayedNotifyErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
