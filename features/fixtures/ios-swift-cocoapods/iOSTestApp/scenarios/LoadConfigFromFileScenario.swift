
import Foundation
import UIKit
import Bugsnag

class LaunchError : Error {

    init() {
    }
}

@objc class LoadConfigFromFileScenario: Scenario {

    override func startBugsnag() {
        let fileConfig = BugsnagConfiguration.loadConfig()
        fileConfig.endpoints.notify = config.endpoints.notify
        fileConfig.endpoints.sessions = config.endpoints.sessions
        config = fileConfig
        Bugsnag.start(with: config)
    }

    override func run() {
        Bugsnag.notifyError(LaunchError())
    }
}
