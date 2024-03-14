class OversizedCrashReportScenario: Scenario {
    
    override func configure() {
        super.configure()
        config.autoTrackSessions = false
        config.enabledErrorTypes.ooms = false
        config.maxStringValueLength = UInt.max
        config.addOnSendError {
            var data = Data(count: 1024 * 1024)
            _ = data.withUnsafeMutableBytes {
                SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
            }
            $0.addMetadata(data.base64EncodedString(), key: "random", section: "test")
            return true
        }
    }
    
    override func run() {
        fatalError("This is a test")
    }
}
