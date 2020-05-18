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

// MetadataStore conformance - presence of required methods is a test in and of itself
class myMetadata: NSObject, BugsnagMetadataStore, BugsnagClassLevelMetadataStore {
    static func addMetadata(_ metadata: [AnyHashable : Any], section sectionName: String) {}
    static func addMetadata(_ metadata: Any?, key: String, section sectionName: String) {}
    static func getMetadata(section sectionName: String) -> NSMutableDictionary? { return NSMutableDictionary() }
    static func getMetadata(section sectionName: String, key: String) -> Any? { return nil }
    static func clearMetadata(section sectionName: String) {}
    static func clearMetadata(section sectionName: String, key: String) {}
    
    func addMetadata(_ metadata: [AnyHashable : Any], section sectionName: String) {}
    func addMetadata(_ metadata: Any?, key: String, section sectionName: String) {}
    func getMetadata(section sectionName: String) -> NSMutableDictionary? { return NSMutableDictionary() }
    func getMetadata(section sectionName: String, key: String) -> Any? { return nil }
    func clearMetadata(section sectionName: String) {}
    func clearMetadata(section sectionName: String, key: String) {}
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
    
    // Also test <BugsnagMetadataStore> behaviour
    func testBugsnagMetadataClass() throws {
        var md = BugsnagMetadata()
        md = BugsnagMetadata(dictionary: ["foo" : "bar"])
        
        md.addMetadata(["key" : "secret"], section: "mental")
        md.addMetadata("spock", key: "kirk", section: "enterprise")
        md.getMetadata(section: "mental")
        md.getMetadata(section: "mental", key: "key")
        md.clearMetadata(section: "enterprise")
        md.clearMetadata(section: "enterprise", key: "key")
    }
    
    func testBugsnagEventClass() throws {
        let event = BugsnagEvent()
        
        event.context = nil
        event.context = "ctx"
        event.errors = []
        event.errors = [BugsnagError()]
        event.groupingHash = nil
        event.groupingHash = "1234"
        event.breadcrumbs = []
        event.breadcrumbs = [BugsnagBreadcrumb()]
        event.apiKey = apiKey
        _ = event.device
        _ = event.app
        _ = event.unhandled
        event.threads = []
        event.threads = [BugsnagThread()]
        event.originalError = nil
        event.originalError = 123
        event.originalError = BugsnagError()
        _ = event.user
        event.setUser("user", withEmail: "email", andName: "name")
    }
    
    func testBugsnagAppClass() throws {
        let app = BugsnagApp()
        
        app.bundleVersion = nil
        app.bundleVersion = "bundle"
        _ = app.bundleVersion
        
        app.codeBundleId = nil
        app.codeBundleId = "bundle"
        _ = app.codeBundleId
        
        app.dsymUuid = nil
        app.dsymUuid = "bundle"
        _ = app.dsymUuid
        
        app.id = nil
        app.id = "bundle"
        _ = app.id
        
        app.releaseStage = nil
        app.releaseStage = "bundle"
        _ = app.releaseStage
        
        app.type = nil
        app.type = "bundle"
        _ = app.type
        
        app.version = nil
        app.version = "bundle"
        _ = app.version
    }

    func testBugsnagBreadcrumbClass() throws {
        let breadcrumb = BugsnagBreadcrumb()
        breadcrumb.type = .manual
        breadcrumb.message = "message"
        breadcrumb.metadata = [:]
    }

    func testBugsnagClientClass() throws {
        var client = BugsnagClient()
        let config = BugsnagConfiguration(apiKey)
        client = BugsnagClient(configuration: config)
        client.notify(ex)
        client.notify(ex) { (event) -> Bool in return false }
        client.notifyError(err)
        client.notifyError(err) { (event) -> Bool in return false }
     
        client.leaveBreadcrumb(withMessage: "msg")
        client.leaveBreadcrumb("msg", metadata: [:], type: .manual)
        client.leaveBreadcrumb(forNotificationName: "name")
        
        client.startSession()
        client.pauseSession()
        client.resumeSession()
        
        client.context = nil
        client.context = ""
        _ = client.context
        
        let _ = client.appDidCrashLastLaunch()
        
        client.setUser("me", withEmail: "memail@foo.com", andName: "you")
        let _ = client.user()
        
        client.addOnSession(block: sessionBlock)
        client.removeOnSession(block: sessionBlock)
        
        client.addOnSendError(block: onSendErrorBlock)
        client.removeOnSendError(block: onSendErrorBlock)
        
        client.addOnBreadcrumb(block: onBreadcrumbBlock)
        client.removeOnBreadcrumb(block: onBreadcrumbBlock)
    }

    func testBugsnagDeviceClass() throws {
        let device = BugsnagDevice()
        
        device.jailbroken = false
        _ = device.jailbroken
        
        device.id = nil
        device.id = "id"
        _ = device.id
        
        device.locale = nil
        device.locale = "locale"
        _ = device.locale
        
        device.manufacturer = nil
        device.manufacturer = "man"
        _ = device.manufacturer
        device.model = nil
        device.model = "model"
        _ = device.model
        device.modelNumber = nil
        device.modelNumber = "model"
        _ = device.modelNumber
        device.osName = nil
        device.osName = "name"
        _ = device.osName
        device.osVersion = nil
        device.osVersion = "version"
        _ = device.osVersion
        device.runtimeVersions = nil
        device.runtimeVersions = [:]
        device.runtimeVersions = ["a" : "b"]
        _ = device.runtimeVersions
        device.totalMemory = nil
        device.totalMemory = 1234
        _ = device.totalMemory
    }

    func testBugsnagEndpointConfigurationlass() throws {
        let epc = BugsnagEndpointConfiguration()
        epc.notify = "notify"
        epc.sessions = "sessions"
    }

    // Also error types
    func testBugsnagErrorClass() throws {
        let e = BugsnagError()
        e.errorClass = nil
        e.errorClass = "class"
        _ = e.errorClass
        e.errorMessage = nil
        e.errorMessage = "msg"
        _ = e.errorMessage
        
        e.type = .cocoa
        e.type = .c
        e.type = .reactNativeJs
    }
}
