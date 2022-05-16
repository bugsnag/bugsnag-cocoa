class OldCrashReportScenario: Scenario {
    
    override func startBugsnag() {
        modifyEventCreationDate()
        config.autoTrackSessions = false
        config.enabledErrorTypes.ooms = false
        super.startBugsnag()
    }
    
    override func run() {
        fatalError("This is a test")
    }
    
    func modifyEventCreationDate() {
        let dir = [NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0],
                   "com.bugsnag.Bugsnag",
                   Bundle.main.bundleIdentifier!,
                   "v1",
                   "KSCrashReports"].joined(separator: "/")
        
        let creationDate = Calendar(identifier: .gregorian).date(byAdding: .day, value: -61, to: Date())!
        
        do {
            for name in try FileManager.default.contentsOfDirectory(atPath: dir) {
                let file = (dir as NSString).appendingPathComponent(name)
                try FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: file)
                NSLog("OldCrashReportScenario: Updated creation date of \((file as NSString).lastPathComponent) to \(creationDate)")
            }
        } catch {
            NSLog("\(error)")
        }
    }
}
