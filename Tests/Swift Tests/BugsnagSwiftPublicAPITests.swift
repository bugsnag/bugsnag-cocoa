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

class FakePlugin: NSObject, BugsnagPlugin {
    func load(_ client: BugsnagClient!) {}
    func unload() {}
}

class BugsnagSwiftPublicAPITests: XCTestCase {

    let apiKey = "01234567890123456789012345678901"
    let ex = NSException(name: NSExceptionName("exception"),
                         reason: "myReason",
                         userInfo: nil)
    let err = NSError(domain: "dom", code: 123, userInfo: nil)
    let sessionBlock: BugsnagOnSessionBlock = { (session) -> Bool in return false }
    let onSendErrorBlock: BugsnagOnSendErrorBlock = { (event) -> Bool in return false }
    let onBreadcrumbBlock: BugsnagOnBreadcrumbBlock = { (breadcrumb) -> Bool in return false }
    
    func testBugsnagClass() throws {
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
        
        Bugsnag.addOnSession(block: sessionBlock)
        Bugsnag.removeOnSession(block: sessionBlock)
        
        Bugsnag.addOnSendError(block: onSendErrorBlock)
        Bugsnag.removeOnSendError(block: onSendErrorBlock)
        
        Bugsnag.addOnBreadcrumb(block: onBreadcrumbBlock)
        Bugsnag.removeOnBreadcrumb(block: onBreadcrumbBlock)
    }
    
    func testBugsnagConfigurationClass() throws {
        let _ = BugsnagConfiguration.loadConfig()
        let config = BugsnagConfiguration(apiKey)

        config.apiKey = apiKey
        config.releaseStage = "stage1"
        config.enabledReleaseStages = nil
        config.enabledReleaseStages = ["one", "two", "three"]
        config.redactedKeys = nil
        config.redactedKeys = ["1", 2, 3]
        config.redactedKeys = ["a", "a", "b"]
        config.context = nil
        config.context = "ctx"
        config.appVersion = nil
        config.appVersion = "vers"
        config.session = URLSession();
        config.sendThreads = .always

        config.onCrashHandler = nil
        config.onCrashHandler = { (writer) in }
        let crashHandler: (@convention(c)(UnsafePointer<BSG_KSCrashReportWriter>) -> Void)? = { writer in }
        config.onCrashHandler = crashHandler
        
        config.autoDetectErrors = true
        config.autoTrackSessions = true
        config.enabledBreadcrumbTypes = .all
        config.bundleVersion = nil
        config.bundleVersion = "bundle"
        config.appType = nil
        config.appType = "appType"
        config.maxBreadcrumbs = 999
        config.persistUser = true
        
        let errorTypes =  BugsnagErrorTypes()
        errorTypes.cppExceptions = true
        errorTypes.ooms = true
        errorTypes.machExceptions = true
        errorTypes.signals = true
        errorTypes.unhandledExceptions = true
        errorTypes.unhandledRejections = true
        config.enabledErrorTypes = errorTypes
        
        config.endpoints = BugsnagEndpointConfiguration()
        config.endpoints = BugsnagEndpointConfiguration(notify: "http://test.com", sessions: "http://test.com")
        
        config.setUser("user", withEmail: "email", andName: "name")
        config.addOnSession(block: sessionBlock)
        config.removeOnSession(block: sessionBlock)
        config.addOnSendError(block:onSendErrorBlock)
        config.removeOnSendError(block: onSendErrorBlock)
        config.addOnBreadcrumb(block: onBreadcrumbBlock)
        config.removeOnBreadcrumb(block: onBreadcrumbBlock)
        
        let plugin = FakePlugin()
        config.add(plugin)
    }
}
