class AppHangFatalDisabledScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.enabledErrorTypes.appHangs = false
        config.enabledErrorTypes.ooms = false
    }
    
    override func run() {
        let timeInterval: TimeInterval = 500
        logDebug("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        logError("Should not have finished sleeping")
    }
}
