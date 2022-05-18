class SendLaunchCrashesSynchronouslyLaunchCompletedScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func run() {
        if eventMode != "report" {
            NSLog(">>> Calling markLaunchCompleted()")
            Bugsnag.markLaunchCompleted()
        }
        super.run()
    }
}
