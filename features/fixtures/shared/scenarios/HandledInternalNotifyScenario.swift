
import Bugsnag
import Foundation

@objc class HandledInternalNotifyScenario: Scenario {

    override func run() {
        let exception = NSException(name: NSExceptionName("Handled Error!"),
                                    reason: "Internally reported a handled event",
                                    userInfo: nil);

        Bugsnag.notify(exception) { (event) -> Bool in
            let frames = [
                ["method":"foo()", "file":"src/Giraffe.mm", "lineNumber": 200],
                ["method":"bar()", "file":"parser.js"],
                ["method":"yes()"]
            ]
            event.attachCustomStacktrace(frames, withType: "unreal")
            return true
        }
    }
}

