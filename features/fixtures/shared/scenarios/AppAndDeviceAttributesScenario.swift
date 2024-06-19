//
// Created by Robin Macharg on 18/05/2020.
// Copyright (c) 2020 Bugsnag. All rights reserved.
//

/**
 * Sends a handled Error to Bugsnag
 */
class AppAndDeviceAttributesScenario: Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false
        config.launchDurationMillis = 1000
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
        after(.seconds(2)) {
            Bugsnag.notifyError(error)
        }
    }
}

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}
