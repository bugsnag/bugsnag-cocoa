class BareboneTestUnhandledErrorScenario: Scenario {
    
    private var payload: Payload!
    
    override func startBugsnag() {
        if eventMode == "report" {
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
        super.startBugsnag()
    }
    
    override func run() {
        NSArray().object(at: 42)
    }
}

struct Payload: Decodable {
    let name: String
}
