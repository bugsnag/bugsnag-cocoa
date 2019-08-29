import UIKit
import Bugsnag

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let arguments = ProcessInfo.processInfo.arguments
        NSLog(arguments.joined(separator: "|"))
        let runMaze = arguments.contains { (argument: String) -> Bool in
            if argument.contains("MAZE_SIMULATOR") {
                return true
            } else {
                return false
            }
        }
        if runMaze {
            loadTestScenario(arguments: arguments)
        }
        return true
    }
    
    internal func loadTestScenario(arguments: Array<String>) {
        var delay: TimeInterval = 0
        var eventType = "none"
        var eventMode = "regular"
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
            } else if argument.contains("EVENT_MODE") {
                eventMode = String(argument.split(separator: "=").last!)
            }
        }
        assert(mockAPIPath.count > 0, "The mock API path must be set prior to triggering events. Event Type: '" + eventType + "'")
        if eventType == "preheat" {
            assert(false)
        }
        
        let config = prepareConfig(apiKey: bugsnagAPIKey, mockAPIPath: mockAPIPath)
        let scenario = Scenario.createScenarioNamed(eventType, withConfig: config)
        scenario.eventMode = eventMode
        triggerEvent(scenario: scenario, delay: delay, mode: eventMode)
    }
    
    internal func prepareConfig(apiKey: String, mockAPIPath: String) -> BugsnagConfiguration {
        let config = BugsnagConfiguration()
        config.apiKey = apiKey
        // Enabling by default to check not only the OOM reporting tests but
        // also that extra reports aren't erroneously sent in other conditions
        // when OOM reporting is enabled
        config.reportOOMs = true
        config.setEndpoints(notify: mockAPIPath, sessions: mockAPIPath)
        return config
    }
    
    func triggerEvent(scenario: Scenario, delay: TimeInterval, mode: String) {
        let when = DispatchTime.now() + delay
        scenario.startBugsnag()
        if mode != "noevent" {
            DispatchQueue.main.asyncAfter(deadline: when) {
                scenario.run()
            }
        }
    }
}
