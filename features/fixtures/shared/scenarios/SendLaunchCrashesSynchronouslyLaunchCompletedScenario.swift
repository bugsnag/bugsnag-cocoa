class SendLaunchCrashesSynchronouslyLaunchCompletedScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func run() {
        if eventMode != "report" {
            logDebug(">>> Calling markLaunchCompleted()")
            Bugsnag.markLaunchCompleted()
        }
        super.run()
    }
}
