//
//  FatalErrorOptionScenario.swift
//  iOSTestApp
//
//  Created by Daria Bialobrzeska on 14/12/2025.
//  Copyright © 2025 Bugsnag. All rights reserved.
//

import Foundation

class FatalErrorOptionScenario: Scenario {
    var errorOptions: BugsnagErrorOptions?

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false;
    }

    override func run() {
        // call notify with fatal option set to true, then next real fatal error should not be caught
        errorOptions = BugsnagErrorOptions()
        errorOptions?.fatal = true

        Bugsnag.notify(NSException(name: .rangeException,
                                   reason: "Manually setting error as fatal"),
                       options:self.errorOptions)

        // should not be sent!
        abort();
    }
}
