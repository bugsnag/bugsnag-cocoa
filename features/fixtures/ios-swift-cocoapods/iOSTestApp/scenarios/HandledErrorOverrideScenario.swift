//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag and overrides the exception name + message
 */
class HandledErrorOverrideScenario: Scenario {

    override func run() {
        super.run()
        let error = NSError(domain: "HandledErrorOverrideScenario", code: 100, userInfo: nil)
        Bugsnag.notifyError(error, block: { report in
            report.errorMessage = "Foo"
            report.errorClass = "Bar"
        })
    }

}
