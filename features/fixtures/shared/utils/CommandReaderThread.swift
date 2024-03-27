//
//  CommandReaderThread.swift
//  iOSTestApp
//
//  Created by Steve Kirkland-Walton on 29/06/2023.
//  Copyright © 2023 Bugsnag. All rights reserved.
//

import Foundation

class CommandReaderThread: Thread {
    let uuidKey = "bugsnagPerformanceCI_lastCommandUUID"
    var fixtureConfig: FixtureConfig
    var commandReceiver: CommandReceiver
    var lastCommandID: String = ""

    init(fixtureConfig: FixtureConfig, commandReceiver: CommandReceiver) {
        self.fixtureConfig = fixtureConfig
        self.commandReceiver = commandReceiver
        self.lastCommandID = UserDefaults.standard.string(forKey: uuidKey) ?? ""
    }

    override func main() {
        while true {
            if self.commandReceiver.canReceiveCommand() {
                receiveNextCommand()
            } else {
                logDebug("A command is already in progress, waiting 1 second more...")
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    func newStartedFetchTask() -> CommandFetchTask {
        let fetchTask = CommandFetchTask(url: fixtureConfig.commandURL, afterCommandID: lastCommandID)
        fetchTask.start()
        return fetchTask
    }

    func saveLastCommandID(uuid: String) {
        lastCommandID = uuid
        UserDefaults.standard.set(uuid, forKey: uuidKey)
    }

    func receiveNextCommand() {
        let maxWaitTime = 5.0
        let pollingInterval = 0.2

        var fetchTask = newStartedFetchTask()
        let startTime = Date()

        logDebug("Command fetch: Command request sent. Waiting for response...")
        while true {
            switch fetchTask.state {
            case CommandFetchState.success:
                logDebug("Command fetch: Request succeeded")
                let command = fetchTask.command!
                if (command.uuid != "") {
                    saveLastCommandID(uuid: command.uuid)
                }
                commandReceiver.receiveCommand(command: command)
                return
            case CommandFetchState.fetching:
                let duration = Date() - startTime
                if duration >= maxWaitTime {
                    fetchTask.cancel()
                    logInfo("Command fetch: Server hasn't responded in \(duration)s (max \(maxWaitTime)). Trying again...")
                    fetchTask = newStartedFetchTask()
                }
                break
            case CommandFetchState.unknownCommandID:
                logInfo("Command fetch: Unknown command ID. Starting from the first command...")
                self.lastCommandID = ""
                fetchTask = newStartedFetchTask()
                break

            case CommandFetchState.failed:
                logInfo("Command fetch: Request failed. Trying again...")
                fetchTask = newStartedFetchTask()
                break
            }
            Thread.sleep(forTimeInterval: pollingInterval)
        }
    }
}

extension Date {
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}

enum CommandFetchState {
    case failed, unknownCommandID, fetching, success
}

class CommandFetchTask {
    var url: URL
    var state = CommandFetchState.failed
    var command: MazeRunnerCommand?
    var task: URLSessionTask?

    init(url: URL, afterCommandID: String) {
        self.url = URL(string: "\(url.absoluteString)?after=\(afterCommandID)")!
    }

    func cancel() {
        task?.cancel()
    }

    func start() {
        logInfo("Fetching next command from \(url)")
        state = CommandFetchState.fetching
        let request = URLRequest(url: url)
        task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                do {
                    logDebug("Command response: \(String(describing: String(data: data, encoding: .utf8)))")
                    let command = try decoder.decode(MazeRunnerCommand.self, from: data)
                    logInfo("Command fetched and decoded")
                    self.command = command;
                    self.state = CommandFetchState.success
                } catch {
                    self.state = CommandFetchState.failed
                    let dataAsString = String(data: data, encoding: .utf8)
                    let isInvalidUUID = dataAsString != nil && dataAsString!.contains("there is no command with a UUID of")
                    if isInvalidUUID {
                        self.state = CommandFetchState.unknownCommandID
                    } else {
                        logError("Failed to fetch command: Invalid Response from \(String(describing: self.url)): [\(String(describing: dataAsString))]: Error is: \(error)")
                    }
                }
            } else if let error = error {
                self.state = CommandFetchState.failed
                logError("Failed to fetch command: HTTP Request to \(String(describing: self.url)) failed: \(error)")
            }
        }
        task?.resume()
    }
}
