import UIKit
import Bugsnag

class InvariantException: NSException {
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        loadTestScenario()
        return true
    }

    internal func loadTestScenario() {
        let arguments = ProcessInfo.processInfo.arguments
        var delay: TimeInterval = 0
        var eventType = "Wait"
        var bugsnagAPIKey = ""
        var mockAPIPath = ""

        for argument in arguments {
            if argument.contains("EVENT_DELAY") {
                let components = argument.split(separator: "=")
                if let interval = TimeInterval(components.last!) {
                    delay = interval
                }
            } else if argument.contains("EVENT_TYPE") {
                eventType = String(argument.split(separator: "=").last!)
            } else if argument.contains("MOCK_API_PATH") {
                mockAPIPath = String(argument.split(separator: "=").last!)
            } else if argument.contains("BUGSNAG_API_KEY") {
                bugsnagAPIKey = String(argument.split(separator: "=").last!)
            }
        }
        assert(mockAPIPath.count > 0, "The mock API path must be set prior to triggering events")
        if eventType == "preheat" {
          assert(false)
        }

        let config = prepareConfig(apiKey: bugsnagAPIKey, mockAPIPath: mockAPIPath)
        let scenario = ClassUtils.instantiateClass(eventType, withConfig: config)
        triggerEvent(scenario: scenario, delay: delay)
    }

    internal func prepareConfig(apiKey: String, mockAPIPath: String) -> BugsnagConfiguration {
        let config = BugsnagConfiguration()
        let url = URL(string: mockAPIPath)
        config.apiKey = apiKey
        config.notifyURL = url
        config.sessionURL = url
        return config
    }

    func triggerEvent(scenario: Scenario, delay: TimeInterval) {
        let when = DispatchTime.now() + delay
        scenario.startBugsnag()

        DispatchQueue.main.asyncAfter(deadline: when) {
            scenario.run()
        }
    }
}
