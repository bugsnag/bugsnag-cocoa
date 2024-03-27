class DisabledReleaseStageManualSessionScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        Bugsnag.startSession()
    }
}
