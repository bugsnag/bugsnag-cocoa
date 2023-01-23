//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Delisa on 2/23/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

import UIKit
import os

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

        log("SKW 1")
        
        Scenario.baseMazeAddress = loadMazeRunnerAddress()
    }

    @IBAction func runTestScenario() {

        log("SKW 2")

        // Cater for multiple calls to run()
        if Scenario.current == nil {

            log("SKW 3")

            prepareScenario()

            log("SKW 4")

            log("Starting Bugsnag for scenario: \(Scenario.current!)")
            Scenario.current!.startBugsnag()
        }
        
        log("SKW 5")

        log("Running scenario: \(Scenario.current!)")
        Scenario.current!.run()
    }

    @IBAction func startBugsnag() {

        log("SKW 6")

        prepareScenario()

        log("Starting Bugsnag for scenario: \(Scenario.current!)")
        Scenario.current!.startBugsnag()
    }

    @IBAction func clearPersistentData(_ sender: Any) {
        log("SKW 7")
        Scenario.clearPersistentData()
    }

    func loadMazeRunnerAddress() -> String {
        // TODO Load dynamically from file
        return "http://bs-local.com:9339";
    }
    
    internal func prepareScenario() {
        log("SKW 9")

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
        log("SKW 10")

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
