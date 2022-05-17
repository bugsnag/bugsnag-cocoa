/**
 * Override default values in config
 */
class AppAndDeviceAttributesConfigOverrideScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false

        self.config.appType = "iLeet"
        self.config.bundleVersion = "12345"
        self.config.context = "myContext"
        self.config.releaseStage = "secondStage"

        super.startBugsnag()
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesConfigOverrideScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
