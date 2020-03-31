
import UIKit
import Bugsnag

@objc class UnhandledInternalNotifyScenario: Scenario {

    override func run() {
        let exception = NSException(name: NSExceptionName("Unhandled Error?!"),
                                    reason: "Internally reported an unhandled event",
                                    userInfo: nil);
        let options = [
            "severity": "info",
            "severityReason": "userCallbackSetSeverity",
            "unhandled": true
            ] as [String : Any]
        Bugsnag.internalClientNotify(exception, withData: options) { report in
            let frames = [
                ["method":"bar()", "file":"foo.js", "lineNumber": 43],
                ["method":"baz()", "file":"[native code]"],
                ["method":"is_done()"]
            ]
            report.attachCustomStacktrace(frames, withType: "fake")
        }
    }
}

