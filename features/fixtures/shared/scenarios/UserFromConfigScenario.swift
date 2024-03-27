//
//  UserFromConfigScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Sends a session and event to Bugsnag which contains a user set from Configuration
 */
internal class UserFromConfigScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.setUser("abc", withEmail: "fake@gmail.com", andName: "Fay K")
    }

    override func run() {
        Bugsnag.startSession()

        let user = Bugsnag.user()
        // set Client.user in the metadata so we can verify that the user set
        // in Configuration is copied over during initialisation
        Bugsnag.addMetadata(user.id, key: "id", section: "clientUserValue")
        Bugsnag.addMetadata(user.email, key: "email", section: "clientUserValue")
        Bugsnag.addMetadata(user.name, key: "name", section: "clientUserValue")

        let error = NSError(domain: "UserFromConfigScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
