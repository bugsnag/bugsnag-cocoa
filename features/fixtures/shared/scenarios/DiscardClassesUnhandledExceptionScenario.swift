class DiscardClassesUnhandledExceptionScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.autoTrackSessions = false
        config.discardClasses = [NSExceptionName.rangeException.rawValue]
        config.addOnSendError {
            precondition(!$0.unhandled, "OnSendError should not be called for discarded errors (NSRangeException)")
            return true
        }
    }

    override func startBugsnag() {
        super.startBugsnag()
        
        if Bugsnag.lastRunInfo?.crashed == true {
            Bugsnag.notify(NSException(name: .notDiscarded, reason: "This exception should not be discarded"))
        }
    }
    
    override func run() {
        NSArray().object(at: 0)
    }
}
