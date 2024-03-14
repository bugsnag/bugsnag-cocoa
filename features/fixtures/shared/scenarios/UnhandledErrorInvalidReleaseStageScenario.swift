class UnhandledErrorInvalidReleaseStageScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.enabledReleaseStages = ["prod"]
    }

    override func run() {
        abort();
    }
}
