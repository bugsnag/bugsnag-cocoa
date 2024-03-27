class HandledErrorInvalidReleaseStageScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.enabledReleaseStages = ["prod"]
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
