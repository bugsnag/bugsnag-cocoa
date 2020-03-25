//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 Sends a handled Error to Bugsnag and overrides the exception name + message
 */
class HandledErrorOverrideScenario: Scenario {

    override func startBugsnag() {
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    fileprivate func logError(_ error: Error)  {
        Bugsnag.notifyError(error) { report in
            report.errorMessage = "Foo"
            report.errorClass = "Bar"
            report.metadata["account"] = [
                "items": [400,200]
            ]
        }
    }

    private func handleError(_ error: NSError)  {
        logError(error)
    }

    override func run() {
        let error = NSError(domain: "HandledErrorOverrideScenario", code: 100, userInfo: nil)
        handleError(error)
    }

}
