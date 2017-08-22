//
//  CrashyUITest.swift
//  CrashyUITest
//
//  Created by Jamie Lynch on 28/07/2017.
//  Copyright © 2017 Simon Maynard. All rights reserved.
//

import XCTest

class CrashyUITest: XCTestCase {
        
    override func setUp() {
        super.setUp()
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExample() {
        XCUIApplication().buttons["Generate Exception"].tap() // throw exception
    }
    
}
