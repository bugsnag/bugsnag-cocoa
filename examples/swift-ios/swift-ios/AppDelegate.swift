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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        /**
         This is the minimum amount of setup required for Bugsnag to work.  Simply add your API key to the app's .plist (Supporting Files/Info.plist) and the application will deliver all error and session notifications to the appropriate dashboard.
         
         You can find your API key in your Bugsnag dashboard under the settings menu.
         */
        Bugsnag.start()

        /**
         Bugsnag behavior can be configured through the plist and/or further extended in code by creating a BugsnagConfiguration object and passing it to [Bugsnag startWithConfiguration].
         
         All subsequent setup is optional, and will configure your Bugsnag setup in different ways. A few common examples are included here, for more detailed explanations please look at the documented configuration options at https://docs.bugsnag.com/platforms/ios/configuration-options/
         */
        
        // Create config object from the application plist
//      let config = BugsnagConfiguration.loadConfig()
        
        // ... or construct an empty object
//      let config = BugsnagConfiguration("YOUR-API-KEY")

        /**
         This sets some user information that will be attached to each error.
         */
//        config.setUser("DefaultUser", withEmail:"Not@real.fake", andName:"Default User")

        /**
         The appVersion will let you see what release an error is present in.  This will be picked up automatically from your build settings, but can be manually overwritten as well.
         */
//        config.appVersion = "1.5.0"

        /**
         When persisting a user you won't need to set the user information everytime the app opens, instead it will be persisted between each app session.
         */
//        config.persistUser = true

        /**
         This option allows you to send more or less detail about errors to Bugsnag.  Setting it to Always or Unhandled means you'll have detailed stacktraces of all app threads available when debugging unexpected errors.
         */
//        config.sendThreads = .always

        /**
         Enabled error types allow you to customize exactly what errors are automatically captured and delivered to your Bugsnag dashboard.  A detailed breakdown of each error type can be found in the configuration option documentation.
         */
//        config.enabledErrorTypes.ooms = false
//        config.enabledErrorTypes.unhandledExceptions = true
//        config.enabledErrorTypes.machExceptions = true

        /**
         If there's information that you do not wish sent to your Bugsnag dashboard, such as passwords or user information, you can set the keys as redacted. When a notification is sent to Bugsnag all keys matching your set filters will be redacted before they leave your application.
         All automatically captured data can be found here: https://docs.bugsnag.com/platforms/ios/automatically-captured-data/.
         */
//        config.redactedKeys = ["password", "credit_card_number"]

        /**
         Finally, start Bugsnag with the specified configuration:
         */
//        Bugsnag.start(with: config)

        return true
    }
}

