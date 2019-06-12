//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 Sends a handled Error to Bugsnag and overrides the exception name + message
 Demonstrates adjusting report depth to exclude common error handling code from grouping
 See: https://docs.bugsnag.com/platforms/ios-objc/reporting-handled-exceptions/#depth
 */
class HandledErrorOverrideScenario: Scenario {

    override func startBugsnag() {
      self.config.shouldAutoCaptureSessions = false;
      super.startBugsnag()
    }

    fileprivate func logError(_ error: Error)  {
        Bugsnag.notifyError(error) { report in
            report.errorMessage = "Foo"
            report.errorClass = "Bar"
            report.depth += 2
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
