//
//  AutoDetectFalseNSExceptionScenario.swift
//  iOSTestApp
//
//  Created by Jamie Lynch on 22/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

/**
 * Raises an unhandled NSException with autoDetectErrors set to false, which should be ignored by Bugsnag
 */
internal class AutoDetectFalseNSExceptionScenario: Scenario {

    override func configure() {
        super.configure()
        self.config.autoTrackSessions = false
        self.config.autoDetectErrors = false
    }

    override func run() {
        NSException.init(name: NSExceptionName("SomeError"), reason: "Something went wrong", userInfo: nil).raise()
    }
}
