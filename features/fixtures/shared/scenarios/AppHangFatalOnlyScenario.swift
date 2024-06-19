class AppHangFatalOnlyScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.appHangThresholdMillis = BugsnagAppHangThresholdFatalOnly
        // Sending synchronously causes an immediate retry upon failure, which creates flakes.
        config.sendLaunchCrashesSynchronously = false
        config.addFeatureFlag(name: "Testing")
    }
    
    override func run() {
        let timeInterval: TimeInterval = 500
        logDebug("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        logError("Should not have finished sleeping")
    }
}
