class DiscardClassesUnhandledCrashScenario: Scenario {
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        config.discardClasses = ["SIGABRT"]
        config.addOnSendError {
            precondition(!$0.unhandled, "OnSendError should not be called for discarded errors (SIGABRT)")
            return true
        }
        super.startBugsnag()
        
        if Bugsnag.lastRunInfo?.crashed == true {
            Bugsnag.notify(NSException(name: .notDiscarded, reason: "This exception should not be discarded"))
        }
    }
    
    override func run() {
        abort()
    }
}
