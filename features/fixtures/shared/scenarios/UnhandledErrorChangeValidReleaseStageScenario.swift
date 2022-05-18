class UnhandledErrorChangeValidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        if (self.eventMode == "noevent") {
          // The event is evaluated whether to be sent
          self.config.releaseStage = "test"
        } else {
          // A crash will occur
          self.config.releaseStage = "prod"
        }
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}
