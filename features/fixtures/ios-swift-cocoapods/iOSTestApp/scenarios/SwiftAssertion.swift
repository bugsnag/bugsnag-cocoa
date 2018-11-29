import Foundation

class SwiftAssertion: Scenario {
    override func startBugsnag() {
      self.config.shouldAutoCaptureSessions = false;
      super.startBugsnag()
    }

    override func run() {
        fatalError("several unfortunate things just happened")
    }
}
