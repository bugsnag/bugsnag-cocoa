class SendLaunchCrashesSynchronouslyFalseScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func startBugsnag() {
        config.sendLaunchCrashesSynchronously = false
        super.startBugsnag()
    }
}
