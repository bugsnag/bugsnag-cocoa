// Copyright (c) 2020 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import Bugsnag

class ViewController: UITableViewController {
    
    private struct Row {
        let title: String
        let action: (ViewController) -> Void
    }
    
    private struct Section {
        let title: String
        let rows: [Row]
        let footer: String
    }
    
    private let sections: [Section] = [
        Section(
            title: "Crashes",
            rows: [
                Row(title: "Uncaught Objective-C Exception") { $0.generateUncaughtException() },
                Row(title: "POSIX Signal") { $0.generatePOSIXSignal() },
                Row(title: "Mach exception") { $0.generateMachException() },
                Row(title: "Memory Corruption") { $0.generateMemoryCorruption() },
                Row(title: "Stack Overflow") { $0.generateStackOverflow() },
                Row(title: "Swift Precondition Failure") { $0.generateAssertionFailure() },
                Row(title: "Out Of Memory") { $0.generateOutOfMemoryError() },
                Row(title: "Uncaught C++ Exception") { $0.generateCxxException() },
                Row(title: "Fatal App Hang") { $0.generateFatalAppHang() },
            ],
            footer: "Events which terminate the app are sent to Bugsnag automatically. Reopen the app after a crash to send reports."),
        
        Section(
            title: "Handled Errors",
            rows: [
                Row(title: "Send error with notifyError()") { $0.sendAnError() },
            ],
            footer: "Events which can be handled gracefully can also be reported to Bugsnag."),
        
        Section(
            title: "Metadata, breadcrumbs, and callbacks",
            rows: [
                Row(title: "Add client metadata") { $0.addClientMetadata() },
                Row(title: "Add filtered metadata") { $0.addFilteredMetadata() },
                Row(title: "Clear metadata") { $0.clearMetadata() },
                Row(title: "Add custom breadcrumb") { $0.addCustomBreadcrumb() },
                Row(title: "Add breadcrumb with callback") { $0.addBreadcrumbWithCallback() },
                Row(title: "Set user") { $0.setUser() },
            ],
            footer: "Adding diagnostic data and modifying how the event shows on the Bugsnag dashboard."),
        
        Section(
            title: "Sessions",
            rows: [
                Row(title: "Start new session") { $0.startNewSession() },
                Row(title: "Pause current session") { $0.pauseCurrentSession() },
                Row(title: "Resume current session") { $0.resumeCurrentSession() },
            ],
            footer: "Demonstrates the methods of manually determining when sessions are created and expire."),
    ]
    
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

    func generateAssertionFailure() {
        AnotherClass.crash3()
    }
    
    func generateOutOfMemoryError() {
        Bugsnag.leaveBreadcrumb(withMessage: "Starting an OutOfMemoryController for an OOM")
        let controller = OutOfMemoryController();
        navigationController?.pushViewController(controller, animated: true)
    }
    
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
    
    // MARK: -
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].title
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.sections[section].footer
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = self.sections[indexPath.section].rows[indexPath.row].title
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.sections[indexPath.section].rows[indexPath.row].action(self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
