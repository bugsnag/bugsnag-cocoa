import Foundation
import Bugsnag

class ModifyBreadcrumbScenario: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;

        self.config.addOnSendError(block: { event in
            event.breadcrumbs.forEach({ crumb in
                if crumb.message == "Cache cleared" {
                    crumb.message = "Cache locked"
                }
            })
            return true
        })
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb(withMessage: "Cache cleared")
        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

}
