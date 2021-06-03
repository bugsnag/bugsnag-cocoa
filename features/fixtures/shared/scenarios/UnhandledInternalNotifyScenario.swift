
import Foundation

@objc class UnhandledInternalNotifyScenario: Scenario {

    override func run() {
        let exception = NSException(name: NSExceptionName("Unhandled Error?!"),
                                    reason: "Internally reported an unhandled event",
                                    userInfo: nil);

        Bugsnag.notify(exception) { (event) -> Bool in
            let frames = [
                ["method":"bar()", "file":"foo.js", "lineNumber": 43],
                ["method":"baz()", "file":"[native code]"],
                ["method":"is_done()"]
            ]
            event.severity = .info
            event.unhandled = true
            event.attachCustomStacktrace(frames, withType: "fake")
            return true
        }
    }
}

