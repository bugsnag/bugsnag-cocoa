class AppAndDeviceAttributesCallbackOverrideScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false

        self.config.addOnSendError { (event) -> Bool in
            event.app.type = "newAppType"
            event.app.releaseStage = "thirdStage"
            event.app.version = "999"
            event.app.bundleVersion = "42"
            event.device.manufacturer = "Nokia"
            event.device.modelNumber = "0898"

            return true
        }
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesCallbackOverrideScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
