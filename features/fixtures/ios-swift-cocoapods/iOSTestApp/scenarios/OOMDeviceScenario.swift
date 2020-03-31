//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag
import WebKit

/**
 * Sends a handled Error to Bugsnag
 */
class OOMDeviceScenario: Scenario {
    
    override func startBugsnag() {
        self.config.releaseStage = "alpha"
        self.config.add(beforeSend: { (rawData, report) -> Bool in
            report.metaData["extra"] = ["shape": "line"]
            return true
        })
        self.config.shouldAutoCaptureSessions = false
        self.config.reportOOMs = true
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.leaveBreadcrumb(withMessage: "Crumb left before crash")
        let config = Bugsnag.configuration()
        config?.releaseStage = "beta"
        let webview = UIWebView.init()
        DispatchQueue.main.async {
            let format = NSString.init(string: "var b = document.createElement('div'); div.innerHTML = 'Hello item %d'; document.documentElement.appendChild(div); var c = document.createElement('div'); div.innerHTML = 'Hello item %d'; document.documentElement.appendChild(div); var d = document.createElement('div'); div.innerHTML = 'Hello item %d'; document.documentElement.appendChild(div);")
            let end = 3000 * 1024
            for i in 0...end {
                let item = NSString.localizedStringWithFormat(format, String(i))
                webview.stringByEvaluatingJavaScript(from: String(item))
                if (i % 1000 == 0) {
                    NSLog("Loaded %d items", i);
                }
            }
        }
    }
}
