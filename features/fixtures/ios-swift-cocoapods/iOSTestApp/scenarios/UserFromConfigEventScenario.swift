//
//  UserFromConfigEventScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 26/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends an event  to Bugsnag which contains a user set from Configuration
 */
internal class UserFromConfigEventScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.setUser("abc", withEmail: "fake@gmail.com", andName: "Fay K")
        super.startBugsnag()
    }

    override func run() {
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
