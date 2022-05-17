class AppAndDeviceAttributesInfiniteLaunchDurationScenario: Scenario {

    override func startBugsnag() {
        config.autoTrackSessions = false
        config.launchDurationMillis = 0
        super.startBugsnag()
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
