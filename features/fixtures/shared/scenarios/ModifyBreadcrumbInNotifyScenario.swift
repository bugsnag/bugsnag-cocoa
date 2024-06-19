import Foundation

class ModifyBreadcrumbInNotifyScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
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
