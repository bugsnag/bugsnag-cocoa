//
//  EnabledBreadcrumbTypesIsNilScenario.swift
//  iOSTestApp
//
//  Created by Robin Macharg on 25/03/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class EnabledBreadcrumbTypesIsNilScenario : Scenario {
    override func startBugsnag() {
        self.config.autoTrackSessions = false;
        self.config.enabledBreadcrumbTypes = []; // aka .none
        super.startBugsnag()
    }
 
    override func run() {
        Bugsnag.leaveBreadcrumb("Noisy event", metadata: nil, type: .log)
        Bugsnag.leaveBreadcrumb("Important event", metadata: nil, type: .process)

        Bugsnag.notifyError(MagicError(domain: "com.example",
                                       code: 43,
                                       userInfo: [NSLocalizedDescriptionKey: "incoming!"]))
    }
}
