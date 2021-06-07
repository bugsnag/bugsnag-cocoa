Feature: Thrown C++ exceptions are captured by Bugsnag

  Background:
    Given I clear all persistent data

  Scenario: Throwing a C++ exception
    When I run "CxxExceptionScenario" and relaunch the app
    And I configure Bugsnag for "CxxExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "P16kaboom_exception"
    And the exception "type" equals "cocoa"
    And the stacktrace is valid for the event
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"

  Scenario: Throwing a C++ exception with unhandled override
    When I run "CxxExceptionOverrideScenario" and relaunch the app
    And I configure Bugsnag for "CxxExceptionOverrideScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "P16kaboom_exception"
    And the exception "type" equals "cocoa"
    And the stacktrace is valid for the event
    And the event "severity" equals "error"
    And the event "unhandled" is false
    And the event "severityReason.unhandledOverridden" is true
    And the event "severityReason.type" equals "unhandledException"
