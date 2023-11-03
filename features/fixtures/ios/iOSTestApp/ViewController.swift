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
    var mazeRunnerAddress: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        apiKeyField.text = UserDefaults.standard.string(forKey: "apiKey")
        logInfo("Read API key from UserDefaults: \(apiKeyField.text!)")

        // Poll for commands to run
        if #available(iOS 10.0, *) {
            let uiUpdater = { (scenarioName: String, eventMode: String) in
                self.scenarioNameField.text = scenarioName
                self.scenarioMetaDataField.text = eventMode
            }

            let thread = CommandReaderThread(action: uiUpdater)
            thread.start()
        }
    }

    @IBAction func runTestScenario() {
        // Cater for multiple calls to run()
        if Scenario.current == nil {
            prepareScenario()

            logInfo("Starting Bugsnag for scenario: \(Scenario.current!)")
            Scenario.current!.startBugsnag()
        }
        
        logInfo("Running scenario: \(Scenario.current!)")
        Scenario.current!.run()
    }

    @IBAction func startBugsnag() {
        prepareScenario()

        logInfo("Starting Bugsnag for scenario: \(Scenario.current!)")
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
            logInfo("Running in manual mode with API key: \(apiKey)")
            UserDefaults.standard.setValue(apiKey, forKey: "apiKey")
            config = BugsnagConfiguration(apiKeyField.text!)
        }
        
        Scenario.createScenarioNamed(scenarioNameField.text!,
                                     withConfig: config)
        Scenario.current!.eventMode = scenarioMetaDataField.text
    }

    @objc func didEnterBackgroundNotification() {
        Scenario.current?.didEnterBackgroundNotification()
    }
}
