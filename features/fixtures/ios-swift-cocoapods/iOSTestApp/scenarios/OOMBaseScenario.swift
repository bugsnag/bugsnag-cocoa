//
//  OOMBaseScenario.swift
//  iOSTestApp
//
//  Created by Alexander Moinet on 12/10/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import Foundation

class OOMBaseScenario: Scenario {
    func createOOMFiles() {
        let state:[String:Any] = [
            "app": [
                "bundleVersion":"5",
                "debuggerIsActive":false,
                "id":"com.bugsnag.iOSTestApp",
                "inForeground":true,
                "version":"1.0.3",
                "type":"iOS",
                "isActive":true
            ]
        ]
        var data = Data.init()
        do {
            data = try JSONSerialization.data(withJSONObject: state, options: [])
        } catch {
            NSLog("Data serialization failed")
            NSLog(error.localizedDescription)
            return
        }
        let cacheDir = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
        if cacheDir == nil {
            NSLog("Cache dir could not be found")
            return
        }
        let stateUrl = NSURL(fileURLWithPath: cacheDir!).appendingPathComponent("bugsnag/state")
        let kvUrl = NSURL(fileURLWithPath: cacheDir!).appendingPathComponent("bsg_kvstore")
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: stateUrl!, withIntermediateDirectories: true, attributes:nil)
            try fileManager.createDirectory(at: kvUrl!, withIntermediateDirectories: true, attributes:nil)
        } catch {
            NSLog("Cache folder creation failed")
            NSLog(error.localizedDescription)
        }
        let systemStateUrl = stateUrl?.appendingPathComponent("system_state.json")
        let isActiveUrl = kvUrl?.appendingPathComponent("isActive")
        let inForegroundUrl = kvUrl?.appendingPathComponent("inForeground")
        
        let baseData = "1".data(using: .utf8)
        do {
            try data.write(to: systemStateUrl!, options: [NSData.WritingOptions.atomic])
            try baseData!.write(to: isActiveUrl!, options: [NSData.WritingOptions.atomic])
            try baseData!.write(to: inForegroundUrl!, options: [NSData.WritingOptions.atomic])
        } catch {
            NSLog("Data writing failed")
            NSLog(error.localizedDescription)
            return
        }
    }
}

