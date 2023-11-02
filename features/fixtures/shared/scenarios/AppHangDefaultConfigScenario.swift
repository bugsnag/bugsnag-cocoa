class AppHangDefaultConfigScenario: Scenario {
    
    override func run() {
        let timeInterval: TimeInterval = 5
        logInfo("Simulating an app hang of \(timeInterval) seconds...")
        Thread.sleep(forTimeInterval: timeInterval)
        logInfo("Finished sleeping")
    }
}
