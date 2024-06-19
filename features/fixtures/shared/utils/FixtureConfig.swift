//
//  FixtureConfig.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 11.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation

@objcMembers class FixtureConfig: NSObject {
    var apiKey: String
    let mazeRunnerURL: URL
    let docsURL: URL
    let tracesURL: URL
    let commandURL: URL
    let metricsURL: URL
    let reflectURL: URL
    var notifyURL: URL
    var sessionsURL: URL

    init(apiKey: String, mazeRunnerBaseAddress: URL) {
        self.apiKey = apiKey
        mazeRunnerURL = mazeRunnerBaseAddress
        docsURL = mazeRunnerBaseAddress.appendingPathComponent("docs")
        tracesURL = mazeRunnerBaseAddress.appendingPathComponent("traces")
        commandURL = mazeRunnerBaseAddress.appendingPathComponent("command")
        metricsURL = mazeRunnerBaseAddress.appendingPathComponent("metrics")
        notifyURL = mazeRunnerBaseAddress.appendingPathComponent("notify")
        sessionsURL = mazeRunnerBaseAddress.appendingPathComponent("sessions")
        reflectURL = mazeRunnerBaseAddress.appendingPathComponent("reflect")
    }
}
