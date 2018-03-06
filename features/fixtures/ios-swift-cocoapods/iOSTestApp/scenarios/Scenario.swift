//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

internal class Scenario {

    let config: BugsnagConfiguration

    required init(config: BugsnagConfiguration) {
        self.config = config
    }


    /**
     * Sets a NOP implementation for the Session Tracking API, preventing delivery
     */
    func disableSessionDelivery() {
        // TODO
    }


    /**
     * Sets a NOP implementation for the Error Reporting API, preventing delivery
     */
    func disableReportDelivery() {
        // TODO
    }

    /**
     * Sets a NOP implementation for the Error Tracking API and the Session Tracking API,
     * preventing delivery
     */
    func disableAllDelivery() {
        self.disableReportDelivery()
        self.disableSessionDelivery()
    }

    func generateException() -> NSException {
        let name = sanitisedClassName()
        let msg = String(format: "Message: %@", name)
        return NSException(name: NSExceptionName(name), reason: msg, userInfo: nil)
    }

    private func sanitisedClassName() -> String { // split in following format: AppName.ClassName
        let clzName = String(describing: self)
        return String(clzName.split(separator: ".")[1])
    }

    /**
     * Executes the test case
     */
    func run() {
        Bugsnag.start(with: self.config)
    }

}
