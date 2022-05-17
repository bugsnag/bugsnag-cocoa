class UnhandledErrorInvalidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.enabledReleaseStages = ["prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}
