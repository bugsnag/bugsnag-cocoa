Feature: Handled Errors and Exceptions

Scenario: Override errorClass and message from a notifyError() callback
    When I run "HandledErrorOverrideScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "Bar"
    And the exception "message" equals "Foo"
    And the event "device.time" is within 30 seconds of the current timestamp
    And the stack trace contains at least one stack frame

Scenario: Reporting an NSError
    When I run "HandledErrorScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "NSError"
    And the exception "message" equals "The operation couldn’t be completed. (HandledErrorScenario error 100.)"
    And the stack trace contains at least one stack frame

Scenario: Reporting a handled exception
    When I run "HandledExceptionScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "HandledExceptionScenario"
    And the exception "message" equals "Message: HandledExceptionScenario"
    And the stack trace contains at least one stack frame

Scenario: Reporting a handled exception's stacktrace
    When I run "NSExceptionShiftScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "Tertiary failure"
    And the exception "message" equals "invalid invariant"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[NSExceptionShiftScenario causeAnException]"
    And the "method" of stack frame 3 equals "-[NSExceptionShiftScenario run]"
