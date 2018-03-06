//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class HandledErrorScenario: Scenario {

    override func run() {
        super.run()
        Bugsnag.notifyError(NSError(domain: "HandledErrorScenario", code: 100, userInfo: nil))
    }

}
