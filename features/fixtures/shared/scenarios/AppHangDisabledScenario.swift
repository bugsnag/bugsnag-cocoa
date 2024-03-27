class AppHangDisabledScenario: Scenario {

    override func configure() {
        super.configure()
        config.enabledErrorTypes.appHangs = false
    }
    
    override func run() {
        let timeInterval: TimeInterval = 5
        logDebug("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        logDebug("Finished sleeping")
    }
}
