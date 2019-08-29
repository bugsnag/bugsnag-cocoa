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

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func runTestScenario() {
        let eventType : String! = scenarioNameField.text
        let eventMode : String! = scenarioMetaDataField.text
        let config = prepareConfig()
        let scenario = Scenario.createScenarioNamed(eventType, withConfig: config)
        scenario.eventMode = eventMode
        os_log("Starting Bugsnag for scenario: %@", log: .default, type: .info, eventType)
        scenario.startBugsnag()
        os_log("Running scenario: %@", log: .default, type: .info, eventType)
        scenario.run()
    }

    @IBAction func startBugsnag() {
        let eventType : String! = scenarioNameField.text
        let eventMode : String! = scenarioMetaDataField.text
        let config = prepareConfig()
        let scenario = Scenario.createScenarioNamed(eventType, withConfig: config)
        scenario.eventMode = eventMode
        os_log("Starting Bugsnag for scenario: %@", log: .default, type: .info, eventType)
        scenario.startBugsnag()
    }

    internal func prepareConfig() -> BugsnagConfiguration {
        let config = BugsnagConfiguration()
        config.apiKey = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
        config.setEndpoints(notify: "http://bs-local.com:9339", sessions: "http://bs-local.com:9339")
        config.reportOOMs = false
        return config
    }

}

