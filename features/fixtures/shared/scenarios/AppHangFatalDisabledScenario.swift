class AppHangFatalDisabledScenario: Scenario {
    
    override func startBugsnag() {
        config.enabledErrorTypes.appHangs = false
        config.enabledErrorTypes.ooms = false
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
