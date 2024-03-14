class AppHangFatalOnlyScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        // Sending synchronously causes an immediate retry upon failure, which creates flakes.
        config.sendLaunchCrashesSynchronously = false
        config.addFeatureFlag(name: "Testing")
    }
    
    override func run() {
        logDebug("Hanging indefinitely...")
        // Use asyncAfter to allow the Appium click event to be handled
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            while true {}
        }
    }
}
