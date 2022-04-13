//
//  ContentView.swift
//  swift-watchos WatchKit Extension
//
//  Created by Karl Stenerud on 13.04.22.
//

import SwiftUI
import Bugsnag

struct ContentView: View {
    var body: some View {
        Button("Crash") {
            NSLog("Pushed")
            generateUncaughtException()
        }
//        Text("Hello, World!")
//            .padding()
    }

    // MARK: - Crashes
    
    func generateUncaughtException() {
        let someJson : Dictionary = ["foo":self]
        do {
            let data = try JSONSerialization.data(withJSONObject: someJson, options: .prettyPrinted)
            print("Received data: %@", data)
        } catch {
            // Why does this crash the app? A very good question.
        }
    }

    func generatePOSIXSignal() {
        AnObjCClass().trap()
    }
    
    func generateMachException() {
        AnObjCClass().accessInvalidMemoryAddress()
    }

    func generateStackOverflow() {
        let items = ["Something!"]
        // Use if statement to remove warning about calling self through any path
        if (items[0] == "Something!") {
            generateStackOverflow()
        }
        print("items: %@", items)
    }

    func generateMemoryCorruption() {
        AnObjCClass().corruptSomeMemory()
    }

//    func generateAssertionFailure() {
//        AnotherClass.crash3()
//    }
//
//    func generateOutOfMemoryError() {
//        Bugsnag.leaveBreadcrumb(withMessage: "Starting an OutOfMemoryController for an OOM")
//        let controller = OutOfMemoryController();
//        navigationController?.pushViewController(controller, animated: true)
//    }
    
    func generateCxxException() {
        AnObjCClass().throwCxxException()
    }

    func generateFatalAppHang() {
        Thread.sleep(forTimeInterval: 3)
        _exit(1)
    }
    
    // MARK: - Handled Errors

    func sendAnError() {
        do {
            try FileManager.default.removeItem(atPath:"//invalid/file")
        } catch {
            Bugsnag.notifyError(error) { event in
                // modify report properties in the (optional) block
                event.severity = .info
                return true
            }
        }
    }
    
    // MARK: - Metadata, breadcrumbs, and callbacks
    
    private enum MetadataSection: String {
        case extras
    }
    
    func addClientMetadata() {
        // This method adds some metadata to your application client, that will be included in all subsequent error reports, and visible on the "extras" tab  on the Bugsnag dashboard.
        Bugsnag.addMetadata("metadata!", key: "client", section: MetadataSection.extras.rawValue)
    }
    
    func addFilteredMetadata() {
        // This method adds some metadata that will be redacted on the Bugsnag dashboard.
        // It will only work if the optional configuration is uncommented in the `AppDelegate.swift` file.
        Bugsnag.addMetadata("secret123", key: "password", section: MetadataSection.extras.rawValue)
    }
    
    func clearMetadata() {
        // This method clears all metadata in the "extras" tab that would be attached to the error reports.
        // It won't clear data that hasn't been added yet, like data attached through a callback.
        Bugsnag.clearMetadata(section: MetadataSection.extras.rawValue)
    }
    
    func addCustomBreadcrumb() {
        // This is the simplest example of leaving a custom breadcrumb.
        // This will show up under the "breadcrumbs" tab of your error on the Bugsnag dashboard.
        Bugsnag.leaveBreadcrumb(withMessage: "This is our custom breadcrumb!")
    }
    
    func addBreadcrumbWithCallback() {
        // This adds a callback to the breadcrumb process, setting a different breadcrumb type if a specific message is present.
        // It leaves a slightly more detailed breadcrumb than before, with a message, metadata, and type all specified.
        Bugsnag.addOnBreadcrumb {
            if $0.message == "Custom breadcrumb name" {
                $0.type = .process
            }
            return true
        }
        Bugsnag.leaveBreadcrumb("Custom breadcrumb name", metadata: ["metadata": "here!"], type: .manual)
    }
    
    func setUser() {
        // This sets a user on the client, similar to setting one on the configuration.
        // It will also set the user in a session payload.
        Bugsnag.setUser("user123", withEmail: "TestUser@example.com", andName: "Test Userson")
    }
    
    // MARK: - Sessions
    
    func startNewSession() {
        // This starts a new session within Bugsnag.
        // While sessions are generally configured to work automatically, this allows you to define when a session begins.
        Bugsnag.startSession()
    }
    
    func pauseCurrentSession() {
        // This pauses the current session.
        // If an error occurs when a session is paused it will not be included in the session statistics for the project.
        Bugsnag.pauseSession()
    }
    
    func resumeCurrentSession() {
        // This allows you to resume the previous session, keeping a record of any errors that previously occurred within a single session intact.
        Bugsnag.resumeSession();
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
