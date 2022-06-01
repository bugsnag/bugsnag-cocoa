//
//  watchOSTestApp.swift
//  watchOSTestApp WatchKit Extension
//
//  Created by Nick Dowell on 01/06/2022.
//

import SwiftUI

@main
struct watchOSTestApp: App {
    @WKExtensionDelegateAdaptor private var extensionDelegate: ExtensionDelegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}

class ExtensionDelegate: NSObject, WKExtensionDelegate, ObservableObject {
    func applicationDidFinishLaunching() {
        Scenario.executeMazeRunnerCommand()
    }
}
