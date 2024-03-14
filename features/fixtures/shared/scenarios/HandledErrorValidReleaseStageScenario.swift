class MagicError : NSError {}

class HandledErrorValidReleaseStageScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
