//
//  NetworkBreadcrumbsScenario.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 10/09/2021.
//  Copyright © 2021 Bugsnag. All rights reserved.
//

import Foundation

class NetworkBreadcrumbsScenario : Scenario {

    override func startBugsnag() {
        self.config.autoTrackSessions = false;

        super.startBugsnag()
    }

    override func run() {

        // Make some network requests so that automatic network breadcrumbs are left
        
        
        // Send a handled error
        let error = NSError(domain: "NetworkBreadcrumbsScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error)
    }
}
