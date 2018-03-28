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

Scenario: Send a message to an object whose memory has already been freed
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "ReleasedObjectScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Attempted to dereference null pointer."
    And the exception "errorClass" equals "SIGSEGV"
    And the "method" of stack frame 0 equals "objc_msgSend"
