import Foundation

class MagicError : NSError {}

class HandledErrorValidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}

class UnhandledErrorValidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}

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

class UnhandledErrorChangeInvalidReleaseStageScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        if (self.eventMode == "noevent") {
          // The event is evaluated whether to be sent
          self.config.releaseStage = "prod"
        } else {
          // A crash will occur
          self.config.releaseStage = "test"
        }
        self.config.enabledReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}

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
