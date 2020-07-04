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
import WebKit

class OutOfMemoryController: UIViewController {
    var webView: WKWebView!

    override func didReceiveMemoryWarning() {
        print("--> Received a low memory warning")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView = WKWebView(frame: self.view.bounds)

        let welcome = """
        <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0, minimum-scale=1.0">
        <h2>Loading a lot of JavaScript. Please wait.</h2>
        <p>You can follow along in Console.app</p>
        """

        self.webView.loadHTMLString(welcome, baseURL: nil)

        self.view.addSubview(self.webView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let format = """
        var div%1$d = document.createElement('div')
        div%1$d.innerHTML = 'Hello item %1$d'
        document.body.appendChild(div%1$d)
        """

        for i in 1...3000 * 1024 {
            self.webView.evaluateJavaScript(String(format: format, i))

            if (i % 5000 == 0) {
                print(String(format: "Loaded %d items", i))
            }
        }
    }
}
