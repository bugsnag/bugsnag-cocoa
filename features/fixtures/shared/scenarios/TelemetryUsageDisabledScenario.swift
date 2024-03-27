class TelemetryUsageDisabledScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.telemetry.remove(.usage)
    }
    
    override func run() {
        Bugsnag.notifyError(NSError(domain: "Test", code: 0))
    }
}
