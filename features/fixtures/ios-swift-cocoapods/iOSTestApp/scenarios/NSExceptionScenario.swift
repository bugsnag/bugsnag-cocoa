//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Raises an NSException which should be received by Bugsnag
 */
class NSExceptionScenario: Scenario {

    override func run() {
        super.run()
        let name = NSExceptionName("Invariant violation")
        InvariantException(name: name, reason: "The cake was rotten", userInfo: nil).raise()
    }

}
