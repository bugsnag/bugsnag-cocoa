//
//  BareboneTestHandledScenario.swift
//  macOSTestApp
//
//  Created by Nick Dowell on 16/12/2020.
//  Copyright © 2020 Bugsnag Inc. All rights reserved.
//

class BareboneTestHandledScenario: Scenario {
    
    var onBreadcrumbCount = 0
    var onSendErrorCount = 0
    var onSessionCount = 0
    
    var afterSendErrorBlock: (() -> Void)?
    
    override func configure() {
        super.configure()
        config.addOnBreadcrumb {
            NSLog("OnBreadcrumb: \"\($0.message)\"")
            self.onBreadcrumbCount += 1
            if $0.message.contains("secret") {
                $0.message = $0.message.replacingOccurrences(of: "secret", with: "<redacted>")
            }
            return true
        }
        config.addOnSendError {
            NSLog("OnSendError: \"\($0.errors[0].errorClass ?? "")\" \"\($0.errors[0].errorMessage ?? "")\"")
            self.onSendErrorCount += 1
            if let block = self.afterSendErrorBlock {
                DispatchQueue.main.async(execute: block)
                self.afterSendErrorBlock = nil
            }
            return true
        }
        config.addOnSession {
            NSLog("OnSession: \($0.id) started at \($0.startedAt)")
            self.onSessionCount += 1
            return true
        }
        config.enabledBreadcrumbTypes = [.error]
        config.autoDetectErrors = false
        config.addMetadata(["Testing": true], section: "Flags")
        config.addMetadata(["password": "123456"], section: "Other")
        config.launchDurationMillis = 0
        config.maxStringValueLength = 100
#if !os(watchOS)
        config.sendThreads = .unhandledOnly
#endif
        config.setUser("foobar", withEmail: "foobar@example.com", andName: "Foo Bar")
        config.addMetadata(["group": "users"], section: "user")
        config.addFeatureFlag(name: "Testing")
        config.addFeatureFlag(name: "fc1", variant: "blue")
        config.addFeatureFlags([
            BugsnagFeatureFlag(name: "fc1"),
            BugsnagFeatureFlag(name: "fc2", variant: "teal"),
            BugsnagFeatureFlag(name: "nope")
        ])
        config.appVersion = "12.3"
        config.bundleVersion = "12301"
    }
    
    override func run() {
        precondition(onSessionCount == 1)
        
        Bugsnag.addFeatureFlag(name: "Bugsnag")
        
        Bugsnag.leaveBreadcrumb(withMessage: "Running BareboneTestHandledScenario")
        
        precondition(onBreadcrumbCount == 1)
        
        Bugsnag.notify(NSException(name: .genericException, reason: nil)) { _ in
            return false
        }
        
        Bugsnag.clearFeatureFlag(name: "nope")
        
        Bugsnag.leaveBreadcrumb(withMessage: "This is super secret")
        
        self.afterSendErrorBlock = self.afterSendError
        
        Bugsnag.addMetadata("""
            Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod \
            tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, \
            quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. \
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu \
            fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in \
            culpa qui officia deserunt mollit anim id est laborum.
            """, key: "shouldBeTruncated", section: "Other")
        
        Bugsnag.notify(NSException(name: .rangeException,
                                   reason: "Something is out of range",
                                   userInfo: ["date": Date(timeIntervalSinceReferenceDate: 0),
                                              "scenario": "BareboneTestHandledScenario",
                                              NSUnderlyingErrorKey: NSError(domain: "ErrorDomain", code: 0)])) {
            $0.addFeatureFlag(name: "notify", variant: "rangeException")
            $0.addMetadata(["info": "Some error specific information"], section: "Exception")
            $0.unhandled = true
            return true
        }
    }
    
    func afterSendError() {
        precondition(onSendErrorCount == 1)
        
        Bugsnag.markLaunchCompleted()
        
        Bugsnag.leaveBreadcrumb(withMessage: "About to decode a payload...")
        
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data())
        } catch {
            Bugsnag.notifyError(error) {
                $0.clearFeatureFlags()
                return true
            }
        }
    }
}
