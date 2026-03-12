//
//  AutoInstrumentNetworkSharedSessionInvalidateScenario.swift
//  Fixture
//
//  Created by Daria Bialobrzeska on 08/03/2026.
//

import Foundation

@available(iOS 10.0, macOS 10.12, *)
class AutoInstrumentNetworkSharedSessionInvalidateScenario: Scenario {
    
    override func configure() {
        super.configure()
        self.config.autoTrackSessions = true;
        config.add(BugsnagNetworkRequestPlugin())
        config.addOnBreadcrumb {
            let url = $0.metadata["url"] as? String ?? ""
            return url.hasPrefix(self.fixtureConfig.mazeRunnerURL.absoluteString) && url.contains("/reflect")
        }
    }
    
    override func run() {
        // Make a network request so that automatic network breadcrumbs are left
        query(string: "/reflect/?status=444&password=T0p5ecr3t")
        URLSession.shared.finishTasksAndInvalidate()
        query(string: "/reflect/?status=444&password=T0p5ecr3t")
        URLSession.shared.invalidateAndCancel()
        query(string: "/reflect/?status=444&password=T0p5ecr3t")


        // Send a handled error
        let error = NSError(domain: "AutoInstrumentNetworkSharedSessionInvalidateScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
    
    func query(string: String) {
        let semaphore = DispatchSemaphore(value: 0)

        let url = URL(string: string, relativeTo: fixtureConfig.reflectURL)!
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
    }
}
