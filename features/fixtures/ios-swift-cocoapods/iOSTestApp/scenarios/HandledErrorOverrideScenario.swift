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
      self.config.autoTrackSessions = false;
      super.startBugsnag()
    }

    fileprivate func logError(_ error: Error)  {
        Bugsnag.notifyError(error) { report in
            let error = report.errors[0] as! BugsnagError
            error.errorMessage = "Foo"
            error.errorClass = "Bar"
            let depth: Int = report.value(forKey: "depth") as! Int
            report.setValue(depth + 2, forKey: "depth")
            report.addMetadata(["items": [400,200]], section: "account")
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
