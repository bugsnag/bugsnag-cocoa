class AppAndDeviceAttributesUnhandledExceptionDuringLaunchScenario: Scenario {

    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }

    override func run() {
        NSException(name: .genericException, reason: "isLaunching should be true").raise()
    }
}
