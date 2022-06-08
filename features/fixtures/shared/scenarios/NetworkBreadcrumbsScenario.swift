//
//  NetworkBreadcrumbsScenario.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 10/09/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import Foundation

@available(iOS 10.0, macOS 10.12, *)
class NetworkBreadcrumbsScenario : Scenario {
    
    lazy var baseURL: URL = {
        var components = URLComponents(string: Scenario.mazeRunnerURL.absoluteString)!
        components.port = 9340 // `/reflect` listens on a different port :-((
        return components.url!
    }()
    
    override func startBugsnag() {
        config.autoTrackSessions = false;
        config.add(BugsnagNetworkRequestPlugin())
        config.addOnBreadcrumb {
            ($0.metadata["url"] as? String ?? "").hasPrefix(self.baseURL.absoluteString)
        }

        super.startBugsnag()
    }

    override func run() {
        // Make some network requests so that automatic network breadcrumbs are left
        query(string: "/reflect/?status=444&password=T0p5ecr3t")
        query(string: "/reflect/?delay_ms=3000")

        // Send a handled error
        let error = NSError(domain: "NetworkBreadcrumbsScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }

    func query(string: String) {
        let url = URL(string: string, relativeTo: baseURL)!
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
    }
}
