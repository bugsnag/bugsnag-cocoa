import UIKit

class ReportBackgroundAppHangScenario: Scenario {

    override func startBugsnag() {
        self.config.appHangThresholdMillis = 1_000
        self.config.reportBackgroundAppHangs = true
        super.startBugsnag()
    }

    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            let backgroundTask = UIApplication.shared.beginBackgroundTask()
            
            let timeInterval: TimeInterval = 2
            NSLog("Simulating an app hang of \(timeInterval) seconds...")
            Thread.sleep(forTimeInterval: timeInterval)
            NSLog("Finished sleeping")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }
}
