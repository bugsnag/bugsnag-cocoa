import UIKit

class AppHangDidBecomeActiveScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.appHangThresholdMillis = 2_000
        self.config.autoTrackSessions = false;
    }
    
    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) {
            logDebug("Received \($0.name), now sleeping for 3 seconds...")
            Thread.sleep(forTimeInterval: 3)
        }
    }
}
