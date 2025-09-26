Feature: Remote config discard rules are applied

  Background:
    Given I clear all persistent data

  Scenario: Empty remote config
    When I run "RemoteConfigScenario" and relaunch the crashed app
    And I configure Bugsnag for "RemoteConfigScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | FooError                | Err 0   		 |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the exception "message" equals "An uncaught exception! SCREAM."
    And the exception "errorClass" equals "NSGenericException"
    And the "method" of stack frame 0 equals the platform-dependent string:
      | ios   | <redacted>            |
      | macos | __exceptionPreprocess |
    And the error payload field "events.0.device.time" is a date
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"
    And on iOS 12 and later, the event "threads.0.name" equals "BSG MAIN THREAD"
    And on macOS 10.14 and later, the event "threads.0.name" equals "BSG MAIN THREAD"
