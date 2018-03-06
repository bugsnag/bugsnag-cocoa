Feature: NSException handling

Scenario: Uncaught NSException is raised
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I set environment variable "EVENT_TYPE" to "HandledExceptionScenario"
    And I set environment variable "SIMULATOR" to "iPhone 8"
    And I install the app
    And I launch the app
    And I set environment variable "EVENT_TYPE" to "Wait"
    And I launch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "HandledExceptionScenario"
    And the exception "message" equals "Message: HandledExceptionScenario"
    And the "machoFile" of stack frame 0 ends with "/CoreFoundation"
