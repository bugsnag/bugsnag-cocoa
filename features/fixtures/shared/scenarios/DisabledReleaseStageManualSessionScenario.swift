class DisabledReleaseStageManualSessionScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false
        self.config.releaseStage = "beta"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.startSession()
    }
}
