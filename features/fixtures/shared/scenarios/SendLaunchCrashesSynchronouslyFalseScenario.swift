class SendLaunchCrashesSynchronouslyFalseScenario: SendLaunchCrashesSynchronouslyScenario {
    
    override func configure() {
        super.configure()
        config.sendLaunchCrashesSynchronously = false
    }
}
