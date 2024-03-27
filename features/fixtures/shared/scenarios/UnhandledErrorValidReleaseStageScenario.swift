class UnhandledErrorValidReleaseStageScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        abort();
    }
}
