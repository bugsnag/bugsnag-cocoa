//
//  BugsnagSwiftPublicAPITests.swift
//  Tests
//
//  Created by Robin Macharg on 15/05/2020.
//  Copyright © 2020 Bugsnag. All rights reserved.
//

import XCTest

/**
 * Test all public APIs from Swift.  Purely existence tests, no attempt to verify correctness
 */

class BugsnagSwiftPublicAPITests: XCTestCase {

    let apiKey = "01234567890123456789012345678901"
    let ex = NSException(name: NSExceptionName("exception"),
                         reason: "myReason",
                         userInfo: nil)
    let err = NSError(domain: "dom", code: 123, userInfo: nil)
    
    func testBugsnag() throws {
        // TODO: prevent init()?
        let bs = Bugsnag()
        
        Bugsnag.start(withApiKey: "")
        Bugsnag.start(withApiKey: apiKey);
        Bugsnag.start(with: BugsnagConfiguration(apiKey))
        
        let _ = Bugsnag.appDidCrashLastLaunch()
        
        Bugsnag.notify(ex)
        Bugsnag.notify(ex) { (event) -> Bool in return false }
        Bugsnag.notifyError(err)
        Bugsnag.notifyError(err) { (event) -> Bool in return false }
        
        Bugsnag.leaveBreadcrumb(withMessage: "msg")
        Bugsnag.leaveBreadcrumb(forNotificationName: "notif")
        Bugsnag.leaveBreadcrumb("msg", metadata: ["foo" : "bar"], type: .error)
        
        Bugsnag.startSession()
        Bugsnag.pauseSession()
        Bugsnag.resumeSession()
        
        Bugsnag.setContext("ctx")
        let _ = Bugsnag.context()
        
        Bugsnag.setUser("me", withEmail: "memail@foo.com", andName: "you")
        let _ = Bugsnag.user()
        
        let sessionBlock: BugsnagOnSessionBlock = { (session) -> Bool in return false }
        Bugsnag.addOnSession(block: sessionBlock)
        Bugsnag.removeOnSession(block: sessionBlock)
        
        let onSendErrorBlock: BugsnagOnSendErrorBlock = { (event) -> Bool in return false }
        Bugsnag.addOnSendError(block: onSendErrorBlock)
        Bugsnag.removeOnSendError(block: onSendErrorBlock)
        
        let onBreadcrumbBlock: BugsnagOnBreadcrumbBlock = { (breadcrumb) -> Bool in return false }
        Bugsnag.addOnBreadcrumb(block: onBreadcrumbBlock)
        Bugsnag.removeOnBreadcrumb(block: onBreadcrumbBlock)
    }

}
