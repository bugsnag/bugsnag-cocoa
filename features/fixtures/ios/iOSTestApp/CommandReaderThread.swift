//
//  CommandReaderThread.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 29/06/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import UIKit
import os

class CommandReaderThread: Thread {
    
    var action: (String, String) -> Void
    init(action: @escaping (String, String) -> Void) {
        self.action = action
    }
    
    override func main() {
        if Scenario.baseMazeAddress.isEmpty {
            Scenario.baseMazeAddress = self.loadMazeRunnerAddress()
        }
        
        var isRunningCommand = false

        while true {
            if isRunningCommand {
                logInfo("A command fetch is already in progress, waiting 1 second more...")
            } else {
                isRunningCommand = true
                Scenario.executeMazeRunnerCommand() { scenarioName, eventMode in
                    if (!scenarioName.isEmpty) {
                        self.action(scenarioName, eventMode)
                    }
                    isRunningCommand = false
                }
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    func loadMazeRunnerAddress() -> String {

        let bsAddress = "http://bs-local.com:9339"

        // Only iOS 12 and above will run on BitBar for now
        if #available(iOS 12.0, *) {} else {
            return bsAddress;
        }
        
        for n in 1...30 {
            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

            logInfo("Reading Maze Runner address from fixture_config.json")
            do {
                let fileUrl = URL(fileURLWithPath: "fixture_config",
                                  relativeTo: documentsUrl).appendingPathExtension("json")

                let savedData = try Data(contentsOf: fileUrl)

                if let contents = String(data: savedData, encoding: .utf8) {
                    logInfo(String(format: "Found fixture_config.json after %d seconds", n))
                    let decoder = JSONDecoder()
                    let jsonData = contents.data(using: .utf8)
                    let config = try decoder.decode(FixtureConfig.self, from: jsonData!)
                    let address = "http://" + config.maze_address
                    logInfo("Using Maze Runner address: " + address)
                    return address
                }
            }
            catch let error as NSError {
                logWarn("Failed to read fixture_config.json: \(error)")
            }
            logInfo("Waiting for fixture_config.json to appear")
            Thread.sleep(forTimeInterval: 1)
        }

        logError("Unable to read from fixture_config.json, defaulting to BrowserStack environment")
        return bsAddress;
    }
}

private func logInfo(_ message: String) {
    let fullMessage = String(format: "bugsnagci info: %s", message)
    NSLog("%@", fullMessage)
    kslog("\(Date()) \(fullMessage)")
}

private func logWarn(_ message: String) {
    let fullMessage = String(format: "bugsnagci warn: %s", message)
    NSLog("%@", fullMessage)
    kslog("\(Date()) \(fullMessage)")
}

private func logError(_ message: String) {
    let fullMessage = String(format: "bugsnagci error: %s", message)
    NSLog("%@", fullMessage)
    kslog("\(Date()) \(fullMessage)")
}
