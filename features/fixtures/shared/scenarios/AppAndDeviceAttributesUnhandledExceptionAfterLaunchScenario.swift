class AppAndDeviceAttributesUnhandledExceptionAfterLaunchScenario: Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false
    }

    override func run() {
        Bugsnag.markLaunchCompleted()
        NSException(name: .genericException, reason: "isLaunching should be false after `Bugsnag.markLaunchCompleted()`").raise()
    }
}
