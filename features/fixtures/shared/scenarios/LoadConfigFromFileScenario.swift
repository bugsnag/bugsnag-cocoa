
import Foundation

class LaunchError : Error {

    init() {
    }
}

@objc class LoadConfigFromFileScenario: Scenario {

    override func startBugsnag() {
        config = BugsnagConfiguration.loadConfig()
        Bugsnag.start(with: config)
    }

    override func run() {
        Bugsnag.notifyError(LaunchError())
    }
}
