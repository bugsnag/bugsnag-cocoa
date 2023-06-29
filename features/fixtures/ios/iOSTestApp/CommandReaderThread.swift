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
        
        while true {
            Scenario.executeMazeRunnerCommand() { scenarioName, eventMode in
                self.action(scenarioName, eventMode)
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    func loadMazeRunnerAddress() -> String {

        // TODO Debug - default to nonsense for now so it also fails on BS
        //let bsAddress = "http://bs-local.com:9339"
        let bsAddress = "http://sdsdfcsdcfewcw:1234"

        // Only iOS 12 and above will run on BitBar for now
        if #available(iOS 12.0, *) {} else {
            return bsAddress;
        }
        
        for n in 1...30 {
            log("SKW0")
            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

            log("Reading Maze Runner address from fixture_config.json")
            do {
                
                log("SKW1")
                
                let fileUrl = URL(fileURLWithPath: "fixture_config",
                                  relativeTo: documentsUrl).appendingPathExtension("json")

                log("SKW2")
                let savedData = try Data(contentsOf: fileUrl)

                log("SKW3")
                if let contents = String(data: savedData, encoding: .utf8) {
                    NSLog("Found fixture_config.json after %d seconds", n)
                    let decoder = JSONDecoder()
                    let jsonData = contents.data(using: .utf8)
                    let config = try decoder.decode(FixtureConfig.self, from: jsonData!)
                    let address = "http://" + config.maze_address
                    log("Using Maze Runner address: " + address)
                    return address
                }

                log("SKW4")
            }
            catch let error as NSError {
                log("Failed to read fixture_config.json: \(error)")
            }
            log("Waiting for fixture_config.json to appear")
            Thread.sleep(forTimeInterval: 1)
        }

        log("Unable to read from fixture_config.json, defaulting to BrowserStack environment")
        return bsAddress;
    }
}

private func log(_ message: String) {
    NSLog("%@", message)
    kslog("\(Date()) \(message)")
}
