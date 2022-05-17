class DisabledReleaseStageAutoSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        // session should be tracked automatically
    }
}
