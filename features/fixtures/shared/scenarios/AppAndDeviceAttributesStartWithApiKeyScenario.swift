/**
 * Call startWithApiKey
 */
class AppAndDeviceAttributesStartWithApiKeyScenario: Scenario {

    override func startBugsnag() {
        BugsnagWrapper.start(withApiKey: "12312312312312312312312312312312")
    }

    override func run() {
        let error = NSError(domain: "AppAndDeviceAttributesStartWithApiKeyScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
