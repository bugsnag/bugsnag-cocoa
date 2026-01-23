//
//  CustomerControlledDeliveryScenario.swift
//  iOSTestApp
//
//  Created by Daria Bialobrzeska on 14/12/2025.
//  Copyright © 2025 Bugsnag. All rights reserved.
//

import Foundation

class CustomerControlledDeliveryScenario: Scenario {
    var counter = 0

    override func configure() {
        super.configure()
        config.autoTrackSessions = false
    }

    override func run() {
    }

    @objc func storeOnlyStrategy() {
        let onSendErrorBlock: BugsnagOnSendErrorBlock = { (event) -> Bool in
            event.deliveryStrategy = BugsnagDeliveryStrategy.StoreOnly
            return true }

        let breadcrumbStr = "Store number: \(counter)"
        Bugsnag.leaveBreadcrumb(breadcrumbStr, metadata: nil, type: .log)
        counter += 1

        Bugsnag.notify(NSException(name: .genericException, reason: "Store only type error"), block:onSendErrorBlock)
    }

    @objc func storeAndFlushStrategy() {
        let onSendErrorBlock: BugsnagOnSendErrorBlock = { (event) -> Bool in
            event.deliveryStrategy = BugsnagDeliveryStrategy.StoreAndFlush
            return true }

        Bugsnag.notify(NSException(name: .rangeException, reason: "Store and flush type error"), block:onSendErrorBlock)
    }

    @objc func storeAndSendStrategy() {
        // prepare some files, not to be flushed
        storeOnlyStrategy();
        storeOnlyStrategy();
        storeOnlyStrategy();

        let onSendErrorBlock: BugsnagOnSendErrorBlock = { (event) -> Bool in
            event.deliveryStrategy = BugsnagDeliveryStrategy.StoreAndSend
            return true }

        Bugsnag.notify(NSException(name: .rangeException, reason: "Store and send type error"), block:onSendErrorBlock)
    }
}
