// Copyright (c) 2016 Bugsnag, Inc. All rights reserved.
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
import CrashReporter

/**
 To enable network breadcrumbs, import the plugin and then add to your config (see configuration section further down).
 You must also update your Podfile to include pod BugsnagNetworkRequestPlugin.
 */
//import BugsnagNetworkRequestPlugin

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var crashReporter: PLCrashReporter?

    func startBugsnag() {
        let config = BugsnagConfiguration("791ac5ad5a73e2409c395a9db2ba033c")

        config.enabledErrorTypes.cppExceptions = false;
        config.enabledErrorTypes.signals = false;
        config.enabledErrorTypes.unhandledExceptions = false;
        config.enabledErrorTypes.machExceptions = true;

        config.addOnSendError { event in
            print("BUGSNAG: Reporting crash \(String(describing: event.errors[0].errorClass)): \(String(describing: event.errors[0].errorMessage))")
            return true
        }

        Bugsnag.start(with: config)

    }

    func startPLCrashReporter() {
        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
        crashReporter = PLCrashReporter(configuration: config)
        if crashReporter == nil {
          print("Could not create an instance of PLCrashReporter")
          return
        }

        // Enable the Crash Reporter.
        do {
          try crashReporter!.enableAndReturnError()
        } catch let error {
          print("Warning: Could not enable crash reporter: \(error)")
        }
    }

    func loadPLCrashReport() {
        if crashReporter!.hasPendingCrashReport() {
          do {
            let data = try crashReporter!.loadPendingCrashReportDataAndReturnError()

            // Retrieving crash reporter data.
            let report = try PLCrashReport(data: data)

            // We could send the report from here, but we'll just print out some debugging info instead.
            if let text = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS) {
              print(text)
            } else {
              print("CrashReporter: can't convert report to text")
            }
          } catch let error {
            print("CrashReporter failed to load and parse with error: \(error)")
          }
        }

        // Purge the report.
        crashReporter!.purgePendingCrashReport()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        startBugsnag()
        startPLCrashReporter()

        Bugsnag.enableAllRemainingHandlers()

        loadPLCrashReport()

        return true
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

