class AppHangFatalOnlyScenario: Scenario {
    
    override func startBugsnag() {
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        // Sending synchronously causes an immediate retry upon failure, which creates flakes.
        config.sendLaunchCrashesSynchronously = false
        config.addFeatureFlag(name: "Testing")
        super.startBugsnag()
    }
    
    override func run() {
        NSLog("Hanging indefinitely...")
        // Use asyncAfter to allow the Appium click event to be handled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            while true {}
        }
    }
}
