//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

@objc open class Scenario: NSObject {

    let config: BugsnagConfiguration

    @objc required public init(config: BugsnagConfiguration) {
        self.config = config
    }

    /**
     * Executes the test case
     */
    func run() {}

    func initBugsnag() {
        Bugsnag.start(with: self.config)
    }

}
