Feature: Handled Errors and Exceptions

  Background:
    Given I clear all persistent data

  Scenario: Reporting a handled exception's stacktrace
    When I run "NSExceptionShiftScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "Tertiary failure"
    And the exception "message" equals "invalid invariant"
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And the event "severityReason.type" equals "handledException"
    And the event "exceptions.0.stacktrace.0.method" equals one of:
      | <redacted>            |
      | __exceptionPreprocess |
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[NSExceptionShiftScenario causeAnException]"
    And the "method" of stack frame 3 equals "-[NSExceptionShiftScenario run]"
