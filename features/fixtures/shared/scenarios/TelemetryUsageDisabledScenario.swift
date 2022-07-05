class TelemetryUsageDisabledScenario: Scenario {
    
    override func startBugsnag() {
        config.telemetry.remove(.usage)
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.notifyError(NSError(domain: "Test", code: 0))
    }
}
