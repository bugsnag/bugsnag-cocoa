//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

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
        DispatchQueue.global(qos: .background).async {
            sleep(2)
            var output = Data.init()
            while true {
                let a = Data.init(repeating: 100, count: 120000000)
                let b = Data.init(repeating: 100, count: 120000000)
                let c = Data.init(repeating: 100, count: 120000000)
                let d = Data.init(repeating: 100, count: 120000000)
                let e = Data.init(repeating: 100, count: 120000000)
                let f = Data.init(repeating: 100, count: 120000000)
                let g = Data.init(repeating: 100, count: 120000000)
                let h = Data.init(repeating: 100, count: 120000000)
                output.append(a)
                output.append(b)
                output.append(c)
                output.append(d)
                output.append(e)
                output.append(f)
                output.append(g)
                output.append(h)
                let bcf = ByteCountFormatter()
                bcf.allowedUnits = [.useMB]
                bcf.countStyle = .memory
                NSLog("Allocated \(bcf.string(fromByteCount: Int64(output.count)))")
            }
        }
    }
    
}
