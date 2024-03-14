import UIKit

class ReportBackgroundAppHangScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.appHangThresholdMillis = 1_000
        self.config.reportBackgroundAppHangs = true
        self.config.addOnSendError { event in
            !event.errors[0].stacktrace.contains { stackframe in
                // CABackingStoreCollectBlocking is known to hang for several seconds upon entering the background
                stackframe.method == "CABackingStoreCollectBlocking"
            }
        }
    }

    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            let backgroundTask = UIApplication.shared.beginBackgroundTask()
            
            let timeInterval: TimeInterval = 2
            logDebug("Simulating an app hang of \(timeInterval) seconds...")
            Thread.sleep(forTimeInterval: timeInterval)
            logDebug("Finished sleeping")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }
}
