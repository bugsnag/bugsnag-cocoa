//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Delisa on 2/23/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var scenarioNameField : UITextField!
    @IBOutlet var scenarioMetaDataField : UITextField!
    @IBOutlet var apiKeyField: UITextField!
    var fixture: Fixture = Fixture(defaultMazeRunnerURL: URL(string: "http://bs-local.com:9339")!, shouldLoadMazeRunnerURL: true)

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        fixture.start()
    }

    override func viewDidLoad() {
        apiKeyField.text = Fixture.defaultApiKey
    }

    @IBAction func runTestScenario() {
        let apiKey = apiKeyField.text!
        let scenarioName = scenarioNameField.text!
        let args = scenarioMetaDataField.text!.count > 0 ? [scenarioMetaDataField.text!] : []

        fixture.setApiKey(apiKey: apiKey)
        fixture.runScenario(scenarioName: scenarioName, args: args, launchCount: 1) {}
    }

    @IBAction func startBugsnag() {
        let apiKey = apiKeyField.text!
        let scenarioName = scenarioNameField.text!
        let args = scenarioMetaDataField.text!.count > 0 ? [scenarioMetaDataField.text!] : []
        
        fixture.setApiKey(apiKey: apiKey)
        fixture.startBugsnagForScenario(scenarioName: scenarioName, args: args, launchCount: 1) {}
    }

    @IBAction func clearPersistentData(_ sender: Any) {
        fixture.clearPersistentData()
    }

    @objc func didEnterBackgroundNotification() {
        fixture.didEnterBackgroundNotification()
    }
}
