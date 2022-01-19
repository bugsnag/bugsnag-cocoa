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

    internal func prepareScenario() {
        var config: BugsnagConfiguration?
        if (apiKeyField.text!.count > 0) {
            // Manual testing mode - use the real dashboard and the API key provided
            let apiKey = apiKeyField.text!
            NSLog("Running in manual mode with API key: %@", apiKey)
            UserDefaults.standard.setValue(apiKey, forKey: "apiKey")
            config = BugsnagConfiguration(apiKeyField.text!)
        }

        Scenario.createScenarioNamed(scenarioNameField.text!, withConfig: config)
        Scenario.current!.eventMode = scenarioMetaDataField.text
    }

    @IBAction func executeCommand(_ sender: Any) {
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
