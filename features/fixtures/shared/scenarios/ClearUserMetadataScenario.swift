//
//  ClearUserMetadataScenario.swift
//  iOSTestApp
//
//  Sends two handled errors:
//   1) with a user set
//   2) after clearing the "user" metadata section, which should also clear subsequent user fields
//

import Foundation

internal class ClearUserMetadataScenario: Scenario {

    override func configure() {
        super.configure()
        // Keep output deterministic for the feature: only the 2 notify() events.
        self.config.autoTrackSessions = false
    }

    override func run() {
        // First event: user is set
        Bugsnag.setUser("u1", withEmail: "u1@example.com", andName: "User 1")

        let before = NSError(domain: "ClearUserMetadataScenario", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "before-clear error 0."
        ])
        Bugsnag.notifyError(before)

        // Clear "user" via metadata API (this is the behavior under test)
        Bugsnag.clearMetadata(section: "user")

        // Second event: after clearing, user fields should be nil on subsequent events
        let after = NSError(domain: "ClearUserMetadataScenario", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "after-clear error 0."
        ])
        Bugsnag.notifyError(after)
    }
}
