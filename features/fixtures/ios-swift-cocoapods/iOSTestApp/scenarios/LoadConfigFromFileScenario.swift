
import Foundation
import UIKit
import Bugsnag

class LaunchError : Error {

    init() {
    }
}

@objc class LoadConfigFromFileScenario: Scenario {

    override func startBugsnag() {
        if let fileConfig = BugsnagConfiguration.loadConfig() {
            fileConfig.setEndpoints(notify: config.notifyURL!.absoluteString,
                                    sessions: config.sessionURL!.absoluteString)
            config = fileConfig
        }
        Bugsnag.start(with: config)
    }

    override func run() {
        Bugsnag.notifyError(LaunchError())
    }
}
