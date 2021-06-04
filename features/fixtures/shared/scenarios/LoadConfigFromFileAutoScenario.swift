
import Foundation

class LoadConfigFromFileAutoScenarioError : Error {

    init() {
    }
}

@objc class LoadConfigFromFileAutoScenario: Scenario {

    override func startBugsnag() {
        Bugsnag.start()
    }

    override func run() {
        Bugsnag.notifyError(LoadConfigFromFileAutoScenarioError())
    }
}
