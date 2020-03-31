
import UIKit
import Bugsnag

@objc class HandledInternalNotifyScenario: Scenario {

    override func run() {
        let exception = NSException(name: NSExceptionName("Handled Error!"),
                                    reason: "Internally reported a handled event",
                                    userInfo: nil);
        let options = [
            "severity": "warning",
            "severityReason": "handledException",
            "unhandled": false
            ] as [String : Any]
        Bugsnag.internalClientNotify(exception, withData: options) { report in
            let frames = [
                ["method":"foo()", "file":"src/Giraffe.mm", "lineNumber": 200],
                ["method":"bar()", "file":"parser.js"],
                ["method":"yes()"]
            ]
            report.attachCustomStacktrace(frames, withType: "unreal")
        }
    }
}

