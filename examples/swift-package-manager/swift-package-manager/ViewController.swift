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
import Bugsnag

class ViewController: UITableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // we're not showing a new UIView so deselect this row
        self.tableView.deselectRow(at: indexPath, animated: true)
        // switch through the UITableView sections
        switch indexPath.section {
        case 0:
            // switch through the rows in 'Crashes'
            switch indexPath.row {
            case 0:
                // Uncaught exception
                generateUncaughtException();
            case 1:
                // POSIX Signal
                generatePOSIXSignal();
            case 2:
                // Memory corruption
                generateMemoryCorruption();
            case 3:
                // Stack overflow
                generateStackOverflow();
            case 4:
                // Assertion failure
                generateAssertionFailure();
            case 5:
                // Out of Memory
                generateOutOfMemoryError();
            case 6:
                // Fatal App Hang
                fatalAppHang()
            default:
                break;
            }
        case 1:
            // switch through the rows in 'Handled Errors'
            switch indexPath.row {
            case 0:
                // Send error with notifyError()
                sendAnError()
            default:
                break;
            }
        default:
            break;
        }
            
    }
    
    func generateUncaughtException() {
        let someJson : Dictionary = ["foo":self]
        do {
            let data = try JSONSerialization.data(withJSONObject: someJson, options: .prettyPrinted)
            print("Received data: %@", data)
        } catch {
            // Why does this crash the app? A very good question.
        }
    }

    func generatePOSIXSignal() {
        raise(SIGTRAP)
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
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 1)
        ptr.storeBytes(of: 0xFFFF_FFFF, as: UInt32.self)

        let badPtr = ptr + 5

        _ = badPtr.load(as: UInt32.self)
    }

    func generateAssertionFailure() {
        preconditionFailure("This should NEVER happen")
    }

    func generateOutOfMemoryError() {
        Bugsnag.leaveBreadcrumb(
            withMessage: "Loading a lot of JavaScript to generate an OOM"
        )

        let controller = OutOfMemoryController()
        navigationController?.pushViewController(controller, animated: true)
    }

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
    
    func fatalAppHang() {
        Thread.sleep(forTimeInterval: 3)
        _exit(1)
    }
}
