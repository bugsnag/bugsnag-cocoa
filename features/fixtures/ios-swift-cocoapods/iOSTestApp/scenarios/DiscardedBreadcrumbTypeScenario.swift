import UIKit

class DiscardedBreadcrumbTypeScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = [.error, .process];
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb { crumb in
            crumb.type = .log
            crumb.message = "Noisy event"
        }
        Bugsnag.leaveBreadcrumb { crumb in
            crumb.type = .process
            crumb.message = "Important event"
        }
        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
