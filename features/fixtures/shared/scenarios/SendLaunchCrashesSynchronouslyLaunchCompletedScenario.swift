class SendLaunchCrashesSynchronouslyLaunchCompletedScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func run() {
        if args[0] != "report" {
            logDebug(">>> Calling markLaunchCompleted()")
            Bugsnag.markLaunchCompleted()
        }
        super.run()
    }
}
