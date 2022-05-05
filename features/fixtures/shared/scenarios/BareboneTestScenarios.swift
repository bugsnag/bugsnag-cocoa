//
//  BareboneTestScenarios.swift
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
    
    override func startBugsnag() {
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
        config.sendThreads = .unhandledOnly
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
        super.startBugsnag()
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
        
        Bugsnag.notify(NSException(name: .rangeException, reason: "-[__NSSingleObjectArrayI objectAtIndex:]: index 1 beyond bounds [0 .. 0]")) {
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

// MARK: -

class BareboneTestUnhandledErrorScenario: Scenario {
    
    private var payload: Payload!
    
    override func startBugsnag() {
        if eventMode == "report" {
            // The version of the app at report time.
            config.appVersion = "23.4"
            config.bundleVersion = "23401"
            config.addOnSendError {
                if let lastRunInfo = Bugsnag.lastRunInfo {
                    $0.addMetadata(
                        ["consecutiveLaunchCrashes": lastRunInfo.consecutiveLaunchCrashes,
                         "crashed": lastRunInfo.crashed,
                         "crashedDuringLaunch": lastRunInfo.crashedDuringLaunch
                        ], section: "lastRunInfo")
                }
                return true
            }
        } else {
            // The version of the app at crash time.
            config.addFeatureFlag(name: "Testing")
            config.addMetadata(["group": "users"], section: "user")
            config.appVersion = "12.3"
            config.bundleVersion = "12301"
            config.context = "Something"
            config.setUser("barfoo", withEmail: "barfoo@example.com", andName: "Bar Foo")
        }
        super.startBugsnag()
    }
    
    override func run() {
        // Triggers "Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value: ..."
        print(payload.name)
    }
}

// MARK: -

private struct Payload: Decodable {
    let name: String
}
