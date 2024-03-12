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
    var fixture: Fixture = Fixture()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fixture.start()
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
