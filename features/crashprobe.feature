Feature: Crashprobe scenarios

Scenario: Abort is reported
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "AbortScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "abort"
    And the "method" of stack frame 2 equals "-[AbortScenario run]"

# N.B. this scenario is "imprecise" on CrashProbe due to line number info,
# which is not tested here as this would require symbolication
Scenario: Swift crash is reported
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "SwiftCrash"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Unexpectedly found nil while unwrapping an Optional value"
    And the exception "errorClass" equals "Fatal error"
