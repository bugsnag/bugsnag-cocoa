import Foundation

class DiscardedBreadcrumbTypeScenario : Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = [.error, .process];
    }

    override func run() {
        // Both are left, despite .log not being enabled.  .state breadcrumbs on the other hand are not left
        Bugsnag.leaveBreadcrumb("Noisy event", metadata: nil, type: .log)
        Bugsnag.leaveBreadcrumb("Important event", metadata: nil, type: .process)

        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
