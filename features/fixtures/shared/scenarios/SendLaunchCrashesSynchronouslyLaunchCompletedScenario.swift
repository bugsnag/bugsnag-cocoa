class SendLaunchCrashesSynchronouslyLaunchCompletedScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func run() {
        if eventMode != "report" {
            logInfo(">>> Calling markLaunchCompleted()")
            Bugsnag.markLaunchCompleted()
        }
        super.run()
    }
}
