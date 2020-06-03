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
    
    var scenario : Scenario?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        apiKeyField.text = UserDefaults.standard.string(forKey: "apiKey")
    }

    @IBAction func runTestScenario() {
        scenario = prepareScenario()
        
        NSLog("Starting Bugsnag for scenario: %@", String(describing: scenario))
        scenario?.startBugsnag()
        NSLog("Running scenario: %@", String(describing: scenario))
        scenario?.run()
    }

    @IBAction func startBugsnag() {
        scenario = prepareScenario()
        NSLog("Starting Bugsnag for scenario: %@", String(describing: scenario))
        scenario?.startBugsnag()
    }
    
    @IBAction func clearUserData(_ sender: Any) {
        NSLog("Clear user defaults")
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    }
    
    internal func prepareScenario() -> Scenario {
        let eventType : String! = scenarioNameField.text
        let eventMode : String! = scenarioMetaDataField.text

        let config: BugsnagConfiguration
        if (apiKeyField.text!.count > 0) {
            // Manual testing mode - use the real dashboard and the API key provided
            let apiKey = apiKeyField.text!
            NSLog("Running in manual mode with API key: %@", apiKey)
            UserDefaults.standard.setValue(apiKey, forKey: "apiKey")
            config = BugsnagConfiguration(apiKeyField.text!)
        }
        else {
            // Automation mode
            config = BugsnagConfiguration("12312312312312312312312312312312")
            config.endpoints = BugsnagEndpointConfiguration(notify: "http://bs-local.com:9339", sessions: "http://bs-local.com:9339")
        }
        
        let allowedErrorTypes = BugsnagErrorTypes()
        allowedErrorTypes.ooms = false
        config.enabledErrorTypes = allowedErrorTypes
        
        let scenario = Scenario.createScenarioNamed(eventType, withConfig: config)
        scenario.eventMode = eventMode
        return scenario
    }
    
    
    @objc func didEnterBackgroundNotification() {
        scenario?.didEnterBackgroundNotification()
    }
}

