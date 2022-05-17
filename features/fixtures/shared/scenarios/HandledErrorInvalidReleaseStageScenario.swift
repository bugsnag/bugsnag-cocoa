class HandledErrorInvalidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.enabledReleaseStages = ["prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
