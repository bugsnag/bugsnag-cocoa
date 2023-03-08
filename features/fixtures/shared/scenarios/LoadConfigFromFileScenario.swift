
import Foundation

class LaunchError : Error {

    init() {
    }
}

@objc class LoadConfigFromFileScenario: Scenario {

    override func startBugsnag() {
        config = BugsnagConfiguration.loadConfig()
        _ = BugsnagWrapper.start(with: config)
    }

    override func run() {
        Bugsnag.notifyError(LaunchError())
    }
}
