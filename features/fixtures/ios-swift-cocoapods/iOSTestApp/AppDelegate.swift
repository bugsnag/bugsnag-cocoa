import UIKit
import Bugsnag

class InvariantException: NSException {}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        loadTestScenario()
        return true
    }

    func triggerEvent(name: String, delay: TimeInterval) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when) {
            if name == "NSException" {
                InvariantException(name: NSExceptionName("Invariant violation"), reason: "The cake was rotten", userInfo: nil).raise()
            }
        }
    }

    func loadTestScenario() {
        let arguments = ProcessInfo.processInfo.arguments
        var delay: TimeInterval = 0
        var eventType = "none"
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

        let config = BugsnagConfiguration()
        config.apiKey = bugsnagAPIKey
        config.notifyURL = URL(string: mockAPIPath)
        Bugsnag.start(with: config)

        triggerEvent(name: eventType, delay: delay)
    }
}
