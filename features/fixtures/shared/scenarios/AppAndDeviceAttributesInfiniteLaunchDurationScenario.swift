class AppAndDeviceAttributesInfiniteLaunchDurationScenario: Scenario {

    override func configure() {
        super.configure()
        config.autoTrackSessions = false
        config.launchDurationMillis = 0
    }

    override func run() {
        after(.seconds(6)) {
            Bugsnag.notify(NSException(name: .genericException, reason: "isLaunching should be true if `launchDurationMillis` is 0"))
        }
    }
}

private func after(_ interval: DispatchTimeInterval, execute work: @escaping @convention(block) () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + interval, execute: work)
}
