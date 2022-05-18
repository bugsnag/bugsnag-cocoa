import UIKit

class AppHangDidEnterBackgroundScenario: Scenario {
    
    override func run() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) {
            NSLog("Recevied \($0.name), now hanging indefinitely...")
            while true {}
        }
    }
}
