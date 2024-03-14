import Foundation

class SwiftAssertionScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        fatalError("several unfortunate things just happened")
    }
}
