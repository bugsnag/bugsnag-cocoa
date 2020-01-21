//
//  BugsnagSwiftConfigurationTests.swift
//  Tests
//
//  Created by Robin Macharg on 22/01/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import XCTest

class BugsnagSwiftConfigurationTests: XCTestCase {

    /**
     * Since Objective C and Swift exception handling are completely separate
     * there's no /simple/ way of testing the ObjC failure modes.  Practically
     * we just ensure the method is available to Swift.
     */
    func testDesignatedInitializerHasCorrectNS_SWIFT_NAME() {
        let config = BugsnagConfiguration(apiKey: DUMMY_APIKEY_32CHAR_1)
        XCTAssertNotNil(config)
        XCTAssertEqual(config.apiKey, DUMMY_APIKEY_32CHAR_1)
    }
}
