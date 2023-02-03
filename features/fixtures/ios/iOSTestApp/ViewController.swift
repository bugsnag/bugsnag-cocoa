//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Delisa on 2/23/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

import UIKit
import os

class FixtureConfig: Codable {
    var maze_address: String
}

class ViewController: UIViewController {

    @IBOutlet var scenarioNameField : UITextField!
    @IBOutlet var scenarioMetaDataField : UITextField!
    @IBOutlet var apiKeyField: UITextField!
    var mazeRunnerAddress: String = "";

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        apiKeyField.text = UserDefaults.standard.string(forKey: "apiKey")
    }

    @IBAction func runTestScenario() {
        // Cater for multiple calls to run()
        if Scenario.current == nil {
            prepareScenario()

            log("Starting Bugsnag for scenario: \(Scenario.current!)")
            Scenario.current!.startBugsnag()
        }
        
        log("Running scenario: \(Scenario.current!)")
        Scenario.current!.run()
    }

    @IBAction func startBugsnag() {
        prepareScenario()

        log("Starting Bugsnag for scenario: \(Scenario.current!)")
        Scenario.current!.startBugsnag()
    }

    @IBAction func clearPersistentData(_ sender: Any) {
        Scenario.clearPersistentData()
    }

    func loadMazeRunnerAddress() -> String {

        let bsAddress = "http://bs-local.com:9339"
        
        // Only iOS 12 and above will run on BitBat for now
        if #available(iOS 12.0, *) {} else {
            return bsAddress;
        }
        
        for _ in 1...60 {
            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

            log("Reading Maze Runner address from fixture_config.json")
            do {
                let fileUrl = URL(fileURLWithPath: "fixture_config",
                                  relativeTo: documentsUrl).appendingPathExtension("json")
                let savedData = try Data(contentsOf: fileUrl)
                if let contents = String(data: savedData, encoding: .utf8) {
                    let decoder = JSONDecoder()
                    let jsonData = contents.data(using: .utf8)
                    let config = try decoder.decode(FixtureConfig.self, from: jsonData!)
                    let address = "http://" + config.maze_address
                    log("Using Maze Runner address: " + address)
                    return address
                }
            }
            catch let error as NSError {
                log("Failed to read fixture_config.json: \(error)")
            }
            log("Waiting for fixture_config.json to appear")
            sleep(1)
        }

        log("Unable to read from fixture_config.json, defaulting to BrowserStack environment")
        return bsAddress;
    }
    
    internal func prepareScenario() {
        var config: BugsnagConfiguration?
        if (apiKeyField.text!.count > 0) {
            // Manual testing mode - use the real dashboard and the API key provided
            let apiKey = apiKeyField.text!
            NSLog("Running in manual mode with API key: %@", apiKey)
            UserDefaults.standard.setValue(apiKey, forKey: "apiKey")
            config = BugsnagConfiguration(apiKeyField.text!)
        }
        
        Scenario.createScenarioNamed(scenarioNameField.text!,
                                     withConfig: config)
        Scenario.current!.eventMode = scenarioMetaDataField.text
    }

    @IBAction func executeCommand(_ sender: Any) {
        Scenario.baseMazeAddress = loadMazeRunnerAddress()
        Scenario.executeMazeRunnerCommand { _, scenarioName, eventMode in
            self.scenarioNameField.text = scenarioName
            self.scenarioMetaDataField.text = eventMode
        }
    }

    @objc func didEnterBackgroundNotification() {
        Scenario.current?.didEnterBackgroundNotification()
    }
}

private func log(_ message: String) {
    NSLog("%@", message)
    kslog("\(Date()) \(message)")
}
