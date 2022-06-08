//
//  InterfaceController.swift
//  swift-watchos WatchKit Extension
//
//  Created by Karl Stenerud on 17.05.22.
//

import WatchKit
import Foundation
import Bugsnag

class InterfaceController: WKInterfaceController {
    var crashy: AnObjCClass = AnObjCClass()

    override func awake(withContext context: Any?) {
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

    // MARK: - Crashes
    
    @IBAction func generateCPPException() {
        crashy.throwCxxException()
    }

    @IBAction func generateObjCException() {
        let someJson : Dictionary = ["foo":self]
        do {
            let data = try JSONSerialization.data(withJSONObject: someJson, options: .prettyPrinted)
            print("Received data: %@", data)
        } catch {
            // Why does this crash the app? A very good question.
        }
    }

    @IBAction func generateHandledError() {
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
    
    @IBAction func addClientMetadata() {
        // This method adds some metadata to your application client, that will be included in all subsequent error reports, and visible on the "extras" tab  on the Bugsnag dashboard.
        Bugsnag.addMetadata("metadata!", key: "client", section: MetadataSection.extras.rawValue)
    }
    
    @IBAction func addFilteredMetadata() {
        // This method adds some metadata that will be redacted on the Bugsnag dashboard.
        // It will only work if the optional configuration is uncommented in the `AppDelegate.swift` file.
        Bugsnag.addMetadata("secret123", key: "password", section: MetadataSection.extras.rawValue)
    }
    
    @IBAction func clearMetadata() {
        // This method clears all metadata in the "extras" tab that would be attached to the error reports.
        // It won't clear data that hasn't been added yet, like data attached through a callback.
        Bugsnag.clearMetadata(section: MetadataSection.extras.rawValue)
    }
    
    @IBAction func addCustomBreadcrumb() {
        // This is the simplest example of leaving a custom breadcrumb.
        // This will show up under the "breadcrumbs" tab of your error on the Bugsnag dashboard.
        Bugsnag.leaveBreadcrumb(withMessage: "This is our custom breadcrumb!")
    }
    
    @IBAction func addBreadcrumbWithCallback() {
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
    
    @IBAction func setUser() {
        // This sets a user on the client, similar to setting one on the configuration.
        // It will also set the user in a session payload.
        Bugsnag.setUser("user123", withEmail: "TestUser@example.com", andName: "Test Userson")
    }

    // MARK: - Sessions
    
    @IBAction func startNewSession() {
        // This starts a new session within Bugsnag.
        // While sessions are generally configured to work automatically, this allows you to define when a session begins.
        Bugsnag.startSession()
    }
    
    @IBAction func pauseCurrentSession() {
        // This pauses the current session.
        // If an error occurs when a session is paused it will not be included in the session statistics for the project.
        Bugsnag.pauseSession()
    }
    
    @IBAction func resumeCurrentSession() {
        // This allows you to resume the previous session, keeping a record of any errors that previously occurred within a single session intact.
        Bugsnag.resumeSession();
    }
}
