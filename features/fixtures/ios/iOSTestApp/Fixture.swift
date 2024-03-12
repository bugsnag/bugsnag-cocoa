//
//  Fixture.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 11.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation

protocol CommandReceiver {
    func canReceiveCommand() -> Bool
    func receiveCommand(command: MazeRunnerCommand)
}

class Fixture: NSObject, CommandReceiver {
    static let defaultMazeRunnerURL = URL(string: "http://bs-local.com:9339")!

    var readyToReceiveCommand = false
    var commandReaderThread: CommandReaderThread?
    var fixtureConfig: FixtureConfig = FixtureConfig(mazeRunnerBaseAddress: defaultMazeRunnerURL)
    var scenario: Scenario? = nil

    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.loadMazeRunnerAddress { address in
                self.fixtureConfig = FixtureConfig(mazeRunnerBaseAddress: address)
                self.beginReceivingCommands(fixtureConfig: self.fixtureConfig)
            }
        }
    }

    func beginReceivingCommands(fixtureConfig: FixtureConfig) {
        readyToReceiveCommand = true
        commandReaderThread = CommandReaderThread(fixtureConfig: fixtureConfig, commandReceiver: self)
        commandReaderThread!.start()
    }

    func canReceiveCommand() -> Bool {
        return readyToReceiveCommand
    }

    func receiveCommand(command: MazeRunnerCommand) {
        readyToReceiveCommand = false
        var isReady = true
        DispatchQueue.main.async {
            logInfo("Executing command [\(command.action)] with args \(command.args)")
            switch command.action {
            case "run_scenario":
                self.runScenario(scenarioName: command.args[0], completion: {
                    self.readyToReceiveCommand = true
                })
                isReady = false;
                break
            case "invoke_method":
                self.invokeMethod(methodName: command.args[0], args: Array(command.args[1...]))
                break
            case "noop":
                break
            default:
                assertionFailure("\(command.action): Unknown command")
            }
            if isReady {
                self.readyToReceiveCommand = true
            }
        }
    }

    private func runScenario(scenarioName: String, completion: @escaping () -> ()) {
        logInfo("========== Running scenario \(scenarioName) ==========")
        let scenarioClass: AnyClass = NSClassFromString("Fixture.\(scenarioName)")!
        logInfo("Loaded scenario class: \(scenarioClass)")
        scenario = (scenarioClass as! Scenario.Type).init(fixtureConfig: fixtureConfig) as Scenario?
        logInfo("Configuring scenario in class \(scenarioClass)")
        scenario!.configure()
        logInfo("Clearing persistent data")
        scenario!.clearPersistentData()
        logInfo("Starting bugsnag performance")
        scenario!.startBugsnag()
        logInfo("Starting scenario in class \(scenarioClass)")
        scenario!.run()
        logInfo("========== Completed scenario \(scenarioName) ==========")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.scenario!.reportMeasurements()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion()
            }
        }
    }

    private func invokeMethod(methodName: String, args: Array<String>) {
        logInfo("Invoking method \(methodName) with args \(args) on \(String(describing: scenario!.self))")

        let sel = NSSelectorFromString(methodName)
        if (!scenario!.responds(to: sel)) {
            fatalError("\(String(describing: scenario!.self)) does not respond to \(methodName). Did you set the @objcMembers annotation on \(String(describing: scenario!.self))?")
        }

        switch args.count {
        case 0:
            scenario!.perform(sel)
        case 1:
            // Note: Parameter must accept a string
            scenario!.perform(sel, with: args[0])
        default:
            fatalError("invoking \(methodName) with args \(args): Fixture currently only supports up to 1 argument")
        }
    }

    func loadMazeRunnerAddress(completion: (URL)->()) {
        let defaultUrl = Fixture.defaultMazeRunnerURL

        // Only iOS 12 and above will run on BitBar for now
        if #available(iOS 12.0, *) {} else {
            completion(defaultUrl)
            return
        }

        for n in 1...60 {
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
                    let config = try decoder.decode(FixtureConfigJSON.self, from: jsonData!)
                    let address = "http://" + config.maze_address
                    logInfo("Using Maze Runner address: \(address)")
                    completion(URL(string: address)!)
                    return
                }
            }
            catch let error as NSError {
                logWarn("Failed to read fixture_config.json: \(error)")
            }
            logInfo("Waiting for fixture_config.json to appear")
            sleep(1)
        }

        logError("Unable to read from fixture_config.json, defaulting to BrowserStack environment")
        completion(defaultUrl)
        return
    }

    private struct FixtureConfigJSON: Decodable {
        var maze_address: String
    }
}
