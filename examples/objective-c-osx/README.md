# Example macOS integration with Bugsnag

This application was made to demonstrate various features of the Bugsnag Cocoa notifier when used in a macOS application written in Objective-C.

When running the application you will see a number of elements that will exercise different features provided by Bugsnag.  These are broadly divided into the following sections:

- Crashes: Events which terminate the app are sent to Bugsnag automatically. Reopen the app after a crash to send reports.
- Handled errors and exceptions: Events which can be handled gracefully can also be reported to Bugsnag.

Specific implementation details can be found in the `ViewController.m` file.

### Running the app

1. Run `pod install`
2. Open the generated workspace in XCode
3. Add your API key to the `bugsnag` dictionary of `Info.plist` 
4. Run the app! There are several examples of different kinds of errors which can be thrown.

#### Configuration examples

A set of configuration examples have been included underneath the minimum setup.  To use, simply comment out the AppDelegate's: `[Bugsnag start]` and uncomment the subsequent configuration lines.

Each line has a brief explanation of what the option does, and for full information please read the documentation at https://docs.bugsnag.com/platforms/macos/configuration-options/.
