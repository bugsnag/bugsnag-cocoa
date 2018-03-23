//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

class HandledExceptionScenario: Scenario {

    override func run() {
        super.run()
        InvariantException(name: NSExceptionName("Invariant violation"), reason: "The cake was rotten", userInfo: nil).raise()
        //Bugsnag.notify(NSException(name: NSExceptionName("HandledExceptionScenario"), reason: "Handled Exception", userInfo: nil))
    }

}
