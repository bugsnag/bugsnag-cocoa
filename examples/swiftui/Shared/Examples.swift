// Copyright (c) 2021 Bugsnag, Inc. All rights reserved.
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

import Bugsnag
import SwiftUI

struct Examples: View {
    var body: some View {
        List {
            Section(header: Text("Crashes"), footer: Text("Events which terminate the app are sent to Bugsnag automatically. Reopen the app after a crash to send reports.")) {
                Button("Uncaught Objective-C Exception", action: generateUncaughtException)
                Button("POSIX Signal", action: generatePOSIXSignal)
                Button("Mach exception", action: generateMachException)
                Button("Memory Corruption", action: generateMemoryCorruption)
                Button("Stack Overflow", action: generateStackOverflow)
                Button("Swift Precondition Failure", action: generateAssertionFailure)
                #if os(iOS)
                NavigationLink("Out Of Memory", destination: OutOfMemoryPresenter())
                #endif
                Button("Uncaught C++ Exception", action: generateCxxException)
                Button("Fatal App Hang", action: generateFatalAppHang)
            }
            Section(header: Text("Handled Errors"), footer: Text("Events which can be handled gracefully can also be reported to Bugsnag.")) {
                Button("Send error with notifyError()", action: sendAnError)
            }
            Section(header: Text("Metadata, breadcrumbs, and callbacks"), footer: Text("Adding diagnostic data and modifying how the event shows on the Bugsnag dashboard.")) {
                Button("Add client metadata", action: addClientMetadata)
                Button("Add filtered metadata", action: addFilteredMetadata)
                Button("Clear metadata", action: clearMetadata)
                Button("Add custom breadcrumb", action: addCustomBreadcrumb)
                Button("Add breadcrumb with callback", action: addBreadcrumbWithCallback)
                Button("Set user", action: setUser)
            }
            Section(header: Text("Sessions"), footer: Text("Demonstrates the methods of manually determining when sessions are created and expire.")) {
                Button("Start new session", action: startNewSession)
                Button("Pause current session", action: pauseCurrentSession)
                Button("Resume current session", action: resumeCurrentSession)
            }
        }
        .navigationTitle("Bugsnag Examples")
    }
}

// MARK: - Crashes

func generateUncaughtException() {
    let someJson : Dictionary = ["foo": Color.green]
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
    preconditionFailure("This should NEVER happen")
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
