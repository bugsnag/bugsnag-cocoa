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

@objc
class Fixture: NSObject, CommandReceiver {
    static let defaultApiKey = "12312312312312312312312312312312"
    @objc static var baseMazeRunnerAddress: URL?

    let defaultMazeRunnerURL: URL
    let shouldLoadMazeRunnerURL: Bool
    var readyToReceiveCommand = false
    var commandReaderThread: CommandReaderThread?
    var fixtureConfig: FixtureConfig
    var currentScenario: Scenario? = nil

    @objc init(defaultMazeRunnerURL: URL, shouldLoadMazeRunnerURL: Bool) {
        self.defaultMazeRunnerURL = defaultMazeRunnerURL
        self.shouldLoadMazeRunnerURL = shouldLoadMazeRunnerURL
        fixtureConfig = FixtureConfig(apiKey: Fixture.defaultApiKey, mazeRunnerBaseAddress: defaultMazeRunnerURL)
    }

    @objc func start() {
        let startFunc: (URL)->() = { address in
            Fixture.baseMazeRunnerAddress = address
            self.fixtureConfig = FixtureConfig(apiKey: Fixture.defaultApiKey, mazeRunnerBaseAddress: address)
            self.beginReceivingCommands(fixtureConfig: self.fixtureConfig)
        }

        if shouldLoadMazeRunnerURL {
            DispatchQueue.global(qos: .userInitiated).async {
                self.loadMazeRunnerAddress(completion: startFunc)
            }
        } else {
            startFunc(fixtureConfig.mazeRunnerURL)
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
                self.runScenario(scenarioName: command.args[0], args: Array(command.args[1...]), launchCount: command.launchCount, completion: {
                    self.readyToReceiveCommand = true
                })
                isReady = false;
                break
            case "start_bugsnag":
                self.startBugsnagForScenario(scenarioName: command.args[0], args: Array(command.args[1...]), launchCount: command.launchCount, completion: {
                    self.readyToReceiveCommand = true
                })
                isReady = false;
                break
            case "invoke_method":
                self.invokeMethod(methodName: command.args[0], args: Array(command.args[1...]))
                break
            case "reset_data":
                self.clearPersistentData()
                break
            case "background":
                self.currentScenario?.enterBackground(forSeconds: Int(command.args[0])!)
                break
            case "wait":
                self.pauseCommandReader(forSeconds: Int(command.args[0])!)
                isReady = false;
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

    @objc func clearPersistentData() {
        Scenario.clearPersistentData()
    }

    @objc func startBugsnagForScenario(scenarioName: String, args: [String], launchCount: Int, completion: @escaping () -> ()) {
        logInfo("---- Starting Bugsnag for scenario \(scenarioName) ----")
        loadScenarioAndStartBugsnag(scenarioName: scenarioName, args: args, launchCount: launchCount)
        logInfo("---- Completed starting Bugsnag for scenario \(String(describing: currentScenario.self)) ----")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }

    @objc func runScenario(scenarioName: String, args: [String], launchCount: Int, completion: @escaping () -> ()) {
        logInfo("---- Running scenario \(scenarioName) ----")
        loadScenarioAndStartBugsnag(scenarioName: scenarioName, args: args, launchCount: launchCount)
        logInfo("Starting scenario in class \(String(describing: currentScenario.self))")
        currentScenario!.run()
        logInfo("---- Completed running scenario \(String(describing: currentScenario.self)) ----")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }

    func pauseCommandReader(forSeconds: Int) {
        logInfo("Pausing command reader for \(forSeconds) seconds")

        self.readyToReceiveCommand = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(forSeconds)) {
            self.readyToReceiveCommand = true
            logInfo("Resuming command reader")
        }
    }
    
    @objc func setApiKey(apiKey: String) {
        self.fixtureConfig.apiKey = apiKey
    }

    @objc func setNotifyEndpoint(endpoint: String) {
        self.fixtureConfig.notifyURL = URL(string: endpoint)!
    }

    @objc func setSessionEndpoint(endpoint: String) {
        self.fixtureConfig.sessionsURL = URL(string: endpoint)!
    }

    func didEnterBackgroundNotification() {
        currentScenario?.didEnterBackgroundNotification()
    }

    private func loadScenarioClass(named: String) -> AnyClass {
        let scenarioName = named
        let namespace = Bundle.main.infoDictionary!["CFBundleExecutable"] as! String
        var scenarioClass: AnyClass?

        scenarioClass = NSClassFromString("\(namespace).\(scenarioName)")
        if scenarioClass != nil {
            return scenarioClass!
        }

        scenarioClass = NSClassFromString(scenarioName)
        if scenarioClass != nil {
            return scenarioClass!
        }

        fatalError("Could not find class \(scenarioName) or \(namespace).\(scenarioName). Aborting scenario load...")
    }

    private func loadScenarioAndStartBugsnag(scenarioName: String, args: [String], launchCount: Int) {
        logInfo("Loading scenario: \(scenarioName)")
        let scenarioClass: AnyClass = loadScenarioClass(named: scenarioName)
        logInfo("Initializing scenario class: \(scenarioClass)")
        let scenario = (scenarioClass as! Scenario.Type).init(fixtureConfig: fixtureConfig, args:args, launchCount: launchCount)
        currentScenario = scenario
        logInfo("Configuring scenario in class \(String(describing: scenario.self))")
        scenario.configure()
        logInfo("Starting bugsnag")
        scenario.startBugsnag()
    }

    private func invokeMethod(methodName: String, args: Array<String>) {
        logInfo("Invoking method \(methodName) with args \(args) on \(String(describing: currentScenario!.self))")

        let sel = NSSelectorFromString(methodName)
        if (!currentScenario!.responds(to: sel)) {
            fatalError("\(String(describing: currentScenario!.self)) does not respond to \(methodName). Did you set the @objcMembers annotation on \(String(describing: currentScenario!.self))?")
        }

        switch args.count {
        case 0:
            currentScenario!.perform(sel)
        case 1:
            // Note: Parameter must accept a string
            currentScenario!.perform(sel, with: args[0])
        default:
            fatalError("invoking \(methodName) with args \(args): Fixture currently only supports up to 1 argument")
        }
    }

    func loadMazeRunnerAddress(completion: (URL)->()) {
        let defaultUrl = defaultMazeRunnerURL

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
