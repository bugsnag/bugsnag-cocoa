class OversizedBreadcrumbsScenario: Scenario {
    
    override func run() {
        
        var metadata: [String: String] = [:]
        for char in "abcdefghij" {
            metadata["\(char)"] = String(repeating: ".", count: 10_000)
        }
        
        for i in 1...25 {
            Bugsnag.leaveBreadcrumb("Breadcrumb \(i)", metadata: metadata, type: .navigation)
        }
        
        Bugsnag.notifyError(NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError))
    }
}
