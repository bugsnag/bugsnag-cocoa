
import UIKit
import Bugsnag

@objc class ReportDidCrashScenario: Scenario {

    override func startBugsnag() {
        self.config.shouldAutoCaptureSessions = false;
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.notifyError(NSError(domain: "com.example", code: 43, userInfo: nil))
    }
}
