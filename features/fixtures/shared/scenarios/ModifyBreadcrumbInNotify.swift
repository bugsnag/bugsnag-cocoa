import Foundation

class ModifyBreadcrumbInNotify: Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        super.startBugsnag()
    }

    override func run() {
        Bugsnag.leaveBreadcrumb(withMessage: "Cache cleared")
        let error = NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error) { event in
            event.breadcrumbs.forEach({ crumb in
                if crumb.message == "Cache cleared" {
                    crumb.message = "Cache locked"
                }
            })
            return true
        }
    }

}
