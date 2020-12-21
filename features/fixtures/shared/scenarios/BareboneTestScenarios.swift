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
            return true
        }
        config.addOnSession {
            NSLog("OnSession: \($0.id) started at \($0.startedAt)")
            self.onSessionCount += 1
            return true
        }
        config.enabledBreadcrumbTypes = [.error]
        config.addMetadata(["Testing": true], section: "Flags")
        config.addMetadata(["password": "123456"], section: "Other")
        config.sendThreads = .unhandledOnly
        config.setUser("foobar", withEmail: "foobar@example.com", andName: "Foo Bar")
        config.appVersion = "12.3"
        config.bundleVersion = "12301"
        super.startBugsnag()
    }
    
    override func run() {
        precondition(onSessionCount == 1)
        
        Bugsnag.leaveBreadcrumb(withMessage: "Running BareboneTestHandledScenario")
        
        precondition(onBreadcrumbCount == 1)
        
        Bugsnag.notify(NSException(name: .genericException, reason: nil)) { _ in
            return false
        }
        
        Bugsnag.leaveBreadcrumb(withMessage: "This is super secret")
        
        Bugsnag.notify(NSException(name: .rangeException, reason: "-[__NSSingleObjectArrayI objectAtIndex:]: index 1 beyond bounds [0 .. 0]")) {
            $0.addMetadata(["info": "Some error specific information"], section: "Exception")
            $0.unhandled = true
            return true
        }
        
        // There is a delay between notify() and an error being sent.
        RunLoop.current.run(until: .init(timeIntervalSinceNow: 2))
        precondition(onSendErrorCount == 1)
        
        Bugsnag.leaveBreadcrumb(withMessage: "About to decode a payload...")
        
        do {
            _ = try JSONDecoder().decode(Payload.self, from: Data())
        } catch {
            Bugsnag.notifyError(error)
        }
    }
}

// MARK: -

class BareboneTestUnhandledErrorScenario: Scenario {
    
    private var payload: Payload!
    
    override func startBugsnag() {
        config.autoTrackSessions = false
        if eventMode == "report" {
            // The version of the app at report time.
            config.appVersion = "23.4"
            config.bundleVersion = "23401"
        } else {
            // The version of the app at crash time.
            config.appVersion = "12.3"
            config.bundleVersion = "12301"
        }
        super.startBugsnag()
    }
    
    override func run() {
        Bugsnag.setUser("barfoo", withEmail: "barfoo@example.com", andName: "Bar Foo")
        
        // Triggers "Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value: ..."
        print(payload.name)
    }
}

// MARK: -

private struct Payload: Decodable {
    let name: String
}
