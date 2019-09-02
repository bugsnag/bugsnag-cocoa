//
// Created by Jamie Lynch on 06/03/2018.
// Copyright (c) 2018 Bugsnag. All rights reserved.
//

import Foundation
import Bugsnag

/**
 * Sends a handled Error to Bugsnag
 */
class ReportOOMsDisabledReportBackgroundOOMsEnabledDeviceScenario: Scenario {
    
    override func startBugsnag() {
        self.config.shouldAutoCaptureSessions = false
        self.config.reportOOMs = false
        self.config.reportBackgroundOOMs = true
        super.startBugsnag()
    }
    
    override func run() {
        DispatchQueue.global(qos: .userInitiated).async {
            sleep(5)
            var output = Data.init()
            while true {
                let a = Data.init(repeating: 100, count: 12000000)
                let b = Data.init(repeating: 100, count: 12000000)
                let c = Data.init(repeating: 100, count: 12000000)
                let d = Data.init(repeating: 100, count: 12000000)
                let e = Data.init(repeating: 100, count: 12000000)
                let f = Data.init(repeating: 100, count: 12000000)
                let g = Data.init(repeating: 100, count: 12000000)
                let h = Data.init(repeating: 100, count: 12000000)
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
