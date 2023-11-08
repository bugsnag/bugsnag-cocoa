//
//  CouldNotCreateDirectoryScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 05/09/2022.
//  Copyright © 2022 Bugsnag Inc. All rights reserved.
//

class CouldNotCreateDirectoryScenario: Scenario {
    
    override func startBugsnag() {
        // Prevent Bugsnag from creating its subdirectories
        
        Scenario.clearPersistentData()
        
        let fileManager = FileManager()
        
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.bugsnag.Bugsnag")
            .appendingPathComponent(Bundle.main.bundleIdentifier!)
        
        try? fileManager.removeItem(at: dir)
        
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dir.path)
            super.startBugsnag()
        } catch {
            logError("\(error)")
        }
    }
    
    override func run() {
    }
}
