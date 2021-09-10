//
//  NetworkBreadcrumbsScenario.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 10/09/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import BugsnagRequestMonitor
import Foundation

class NetworkBreadcrumbsScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.add(BugsnagRequestMonitor())
        
        super.startBugsnag()
    }

    override func run() {

        // Make some network requests so that automatic network breadcrumbs are left
        query(address: "http://bs-local.com:9340/?status=444")
        query(address: "http://bs-local.com:9340/?delay_ms=3000")

        // Send a handled error
        let error = NSError(domain: "NetworkBreadcrumbsScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
    
    func query(address: String) {
        let url = URL(string: address)!
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
    }
}
