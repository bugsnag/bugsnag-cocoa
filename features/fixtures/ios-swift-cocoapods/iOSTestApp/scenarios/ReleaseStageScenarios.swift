import UIKit

class MagicError : NSError {}

class NotifyWhenReleaseStageInNotifyReleaseStages : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.notifyReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}

class CrashWhenReleaseStageInNotifyReleaseStages : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "prod"
        self.config.notifyReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}

class CrashWhenReleaseStageInNotifyReleaseStagesChanges : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        if (self.eventMode == "noevent") {
          // The event is evaluated whether to be sent
          self.config.releaseStage = "test"
        } else {
          // A crash will occur
          self.config.releaseStage = "prod"
        }
        self.config.notifyReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}

class CrashWhenReleaseStageNotInNotifyReleaseStagesChanges : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        if (self.eventMode == "noevent") {
          // The event is evaluated whether to be sent
          self.config.releaseStage = "prod"
        } else {
          // A crash will occur
          self.config.releaseStage = "test"
        }
        self.config.notifyReleaseStages = ["dev", "prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}

class NotifyWhenReleaseStageNotInNotifyReleaseStages : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.notifyReleaseStages = ["prod"]
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}

class CrashWhenReleaseStageNotInNotifyReleaseStages : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.releaseStage = "dev"
        self.config.notifyReleaseStages = ["prod"]
        super.startBugsnag()
    }

    override func run() {
        abort();
    }
}
