//
//  FixtureConfig.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 11.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation

@objc class FixtureConfig: NSObject {
    let mazeRunnerURL: URL
    let tracesURL: URL
    let commandURL: URL
    let metricsURL: URL
    let reflectURL: URL
    let notifyURL: URL
    let sessionsURL: URL

    init(mazeRunnerBaseAddress: URL) {
        mazeRunnerURL = mazeRunnerBaseAddress
        tracesURL = mazeRunnerBaseAddress.appendingPathComponent("traces")
        commandURL = mazeRunnerBaseAddress.appendingPathComponent("command")
        metricsURL = mazeRunnerBaseAddress.appendingPathComponent("metrics")
        notifyURL = mazeRunnerBaseAddress.appendingPathComponent("notify")
        sessionsURL = mazeRunnerBaseAddress.appendingPathComponent("sessions")
        reflectURL = mazeRunnerBaseAddress.appendingPathComponent("reflect")
    }
}
