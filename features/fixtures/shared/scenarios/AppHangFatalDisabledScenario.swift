class AppHangFatalDisabledScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.enabledErrorTypes.appHangs = false
        config.enabledErrorTypes.ooms = false
    }
    
    override func run() {
        logDebug("Hanging indefinitely...")
        // Use asyncAfter to allow the Appium click event to be handled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            while true {}
        }
    }
}
