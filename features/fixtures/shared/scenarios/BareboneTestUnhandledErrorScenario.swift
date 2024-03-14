class BareboneTestUnhandledErrorScenario: Scenario {
    
    private var payload: Payload!
    
    override func configure() {
        super.configure()
        if args[0] == "report" {
            // The version of the app at report time.
            config.appVersion = "23.4"
            config.bundleVersion = "23401"
            config.addOnSendError {
                if let lastRunInfo = Bugsnag.lastRunInfo {
                    $0.addMetadata(
                        ["consecutiveLaunchCrashes": lastRunInfo.consecutiveLaunchCrashes,
                         "crashed": lastRunInfo.crashed,
                         "crashedDuringLaunch": lastRunInfo.crashedDuringLaunch
                        ], section: "lastRunInfo")
                }
                return true
            }
        } else {
            // The version of the app at crash time.
            config.addFeatureFlag(name: "Testing")
            config.addMetadata(["group": "users"], section: "user")
            config.appVersion = "12.3"
            config.bundleVersion = "12301"
            config.context = "Something"
            config.setUser("barfoo", withEmail: "barfoo@example.com", andName: "Bar Foo")
        }
    }
    
    override func run() {
        // Manually constructing an exception to verify handling of userInfo
        NSException(
            name: .rangeException,
            reason: "Something is out of range",
            userInfo: [
                "date": Date(timeIntervalSinceReferenceDate: 0),
                "scenario": "BareboneTestUnhandledErrorScenario",
                NSUnderlyingErrorKey: NSError(domain: "ErrorDomain", code: 0)])
        .raise()
    }
}

struct Payload: Decodable {
    let name: String
}
