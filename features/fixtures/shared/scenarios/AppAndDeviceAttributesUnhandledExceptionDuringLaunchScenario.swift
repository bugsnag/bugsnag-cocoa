class AppAndDeviceAttributesUnhandledExceptionDuringLaunchScenario: Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false
    }

    override func run() {
        NSException(name: .genericException, reason: "isLaunching should be true").raise()
    }
}
