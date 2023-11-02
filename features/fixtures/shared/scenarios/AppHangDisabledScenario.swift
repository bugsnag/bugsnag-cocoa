class AppHangDisabledScenario: Scenario {

    override func startBugsnag() {
        config.enabledErrorTypes.appHangs = false
        super.startBugsnag()
    }
    
    override func run() {
        let timeInterval: TimeInterval = 5
        logInfo("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        logInfo("Finished sleeping")
    }
}
