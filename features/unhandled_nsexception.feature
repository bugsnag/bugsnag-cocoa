Feature: Uncaught NSExceptions are captured by Bugsnag

Scenario: Throw a NSException
    When I run "ObjCExceptionScenario" and relaunch the app
    And I configure Bugsnag for "ObjCExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "An uncaught exception! SCREAM."
    And the exception "errorClass" equals "NSGenericException"
    And the "method" of stack frame 0 equals "<redacted>"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[ObjCExceptionScenario run]"
    And the event "device.time" is within 60 seconds of the current timestamp
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"
