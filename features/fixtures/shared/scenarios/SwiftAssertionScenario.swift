import Foundation

class SwiftAssertionScenario: Scenario {
    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    override func run() {
        fatalError("several unfortunate things just happened")
    }
}
