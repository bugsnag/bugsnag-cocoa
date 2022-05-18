class AppAndDeviceAttributesUnhandledExceptionAfterLaunchScenario: Scenario {

    override func startBugsnag() {
        config.autoTrackSessions = false
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.markLaunchCompleted()
        NSException(name: .genericException, reason: "isLaunching should be false after `Bugsnag.markLaunchCompleted()`").raise()
    }
}
