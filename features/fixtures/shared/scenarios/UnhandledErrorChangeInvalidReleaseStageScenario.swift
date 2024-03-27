class UnhandledErrorChangeInvalidReleaseStageScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        if (args[0] == "noevent") {
          // The event is evaluated whether to be sent
          self.config.releaseStage = "prod"
        } else {
          // A crash will occur
          self.config.releaseStage = "test"
        }
        self.config.enabledReleaseStages = ["dev", "prod"]
    }

    override func run() {
        abort();
    }
}
