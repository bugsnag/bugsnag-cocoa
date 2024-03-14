class DisabledReleaseStageAutoSessionScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        // session should be tracked automatically
    }
}
