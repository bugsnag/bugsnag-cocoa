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

class ViewController: UIViewController {

    @IBAction func doCrash(_ sender: AnyObject) {
        unhandledCrash()
    }

    func unhandledCrash() {
        AnObjCClass().raise()
    }

    func handledError() {
        let error = NSError(domain: "com.bugsnag", code: 402, userInfo: nil)
        Bugsnag.notifyError(error)
    }

    func handledException() {
        let ex = NSException(name: NSExceptionName("handled exception"), reason: "Should've had coffee", userInfo: nil)
        Bugsnag.notify(ex)
    }

    func callbackModifiedException() {
        let ex = NSException(name: NSExceptionName("handled exception in callback"), reason: "Should've had coffee", userInfo: nil)
        Bugsnag.notify(ex) { (report) in
            report.severity = .info
        }
    }

    func userSetSeverity() {
        let ex = NSException(name: NSExceptionName("handled exception with custom severity"), reason: "Should've had coffee", userInfo: nil)
        Bugsnag.notify(ex, withData: nil, atSeverity: "error")
    }

    func signal() {
        AnObjCClass().trap()
    }
}
