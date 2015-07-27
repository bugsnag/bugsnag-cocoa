//
//  AnotherClass.swift
//  bugsnag-example
//
//  Created by Isaac Waller on 4/2/15.
//  Copyright (c) 2015 Isaac Waller. All rights reserved.
//

class AnotherClass: NSObject {

    func crash() {
        crash2()
    }

    func crash2() {
        makingAStackTrace() {
            let objC = AnObjCClass()
            objC.makeAStackTrace(self)
        }
    }

    func makingAStackTrace(block: () -> ()) {
        block()
    }

    func crash3() {
        Bugsnag.notify(NSException(name: "Test error", reason: "Testing if this works", userInfo: nil))
    }
}
