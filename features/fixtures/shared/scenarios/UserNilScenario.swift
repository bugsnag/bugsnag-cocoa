class UserNilScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        Bugsnag.setUser(nil, withEmail: nil, andName: nil)

        // This session should have a non-nil user.id
        Bugsnag.startSession()

        Bugsnag.addOnSession { session in
            session.setUser(nil, withEmail: nil, andName: nil)
            return true
        }

        // This session should have a nil user.id, due to the OnSession block
        Bugsnag.startSession()

        Bugsnag.notifyError(NSError(domain: "ErrorWithCallback", code: 100)) { event in
            // This error should have a nil user.id
            event.setUser(nil, withEmail: nil, andName: nil)
            return true
        }
    }
}
