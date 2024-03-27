//
//  UserInfoScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 19/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a handled error to Bugsnag which  includes the default user information
 */
internal class UserInfoScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        var error = NSError(domain: "UserDefaultInfo", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)

        Bugsnag.setUser(nil, withEmail: nil, andName: nil)
        error = NSError(domain: "UserDisabled", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)

        Bugsnag.setUser(nil, withEmail: "user@example.com", andName: nil)
        error = NSError(domain: "UserEmail", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)

        Bugsnag.setUser("123", withEmail: "user2@example.com", andName: "Joe Bloggs")
        error = NSError(domain: "UserEnabled", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
