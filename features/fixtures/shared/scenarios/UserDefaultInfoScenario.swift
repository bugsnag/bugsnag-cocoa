//
//  UserDefaultInfoScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 19/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled error to Bugsnag which  includes the default user information
 */
internal class UserDefaultInfoScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "UserDefaultInfoScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)

        after(.seconds(1)) {
            Bugsnag.setUser(nil, withEmail: nil, andName: nil)
            let error = NSError(domain: "UserDisabledScenario", code: 100, userInfo: nil)
            Bugsnag.notifyError(error)
        }

        after(.seconds(2)) {
            Bugsnag.setUser(nil, withEmail: "user@example.com", andName: nil)
            let error = NSError(domain: "UserEmailScenario", code: 100, userInfo: nil)
            Bugsnag.notifyError(error)
        }

        after(.seconds(3)) {
            Bugsnag.setUser("123", withEmail: "user@example.com", andName: "Joe Bloggs")
            let error = NSError(domain: "UserEnabledScenario", code: 100, userInfo: nil)
            Bugsnag.notifyError(error)
        }
    }
}

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}
