Feature: Thrown C++ exceptions are captured by Bugsnag

  Background:
    Given I clear all persistent data

  Scenario: Throwing a C++ exception
    When I run "CxxExceptionScenario" and relaunch the crashed app
    And I configure Bugsnag for "CxxExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "PSt13runtime_error"
    And the exception "type" equals "cocoa"
    And the "method" of stack frame 0 equals "-[CxxExceptionScenario crash]"
    And the stacktrace is valid for the event
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"
    And on iOS 12 and later, the event "threads.0.name" equals "потік"
    And on macOS 10.14 and later, the event "threads.0.name" equals "потік"

  Scenario: Throwing a C++ exception with unhandled override
    When I run "CxxExceptionOverrideScenario" and relaunch the crashed app
    And I configure Bugsnag for "CxxExceptionOverrideScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "PSt13runtime_error"
    And the exception "type" equals "cocoa"
    And the "method" of stack frame 0 equals "-[CxxExceptionOverrideScenario crash]"
    And the stacktrace is valid for the event
    And the event "severity" equals "error"
    And the event "unhandled" is false
    And the event "severityReason.unhandledOverridden" is true
    And the event "severityReason.type" equals "unhandledException"
    And on iOS 12 and later, the event "threads.0.name" equals "BSG MAIN THREAD"
    And on macOS 10.14 and later, the event "threads.0.name" equals "BSG MAIN THREAD"

  Scenario Outline: The original C++ throw site is retained
    When I run "<scenario>" and relaunch the crashed app
    And I configure Bugsnag for "<scenario>"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "St13runtime_error"
    And the exception "message" equals "Original exception on the crashing thread"
    And the stacktrace contains methods:
      | -[CxxConcurrentExceptionScenario crash] |
    And the "method" of stack frame 0 equals "-[CxxConcurrentExceptionScenario crash]"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"

    Examples:
      | scenario                                 |
      | CxxConcurrentExceptionScenario           |
      | CxxConcurrentExceptionBackgroundScenario |
      | CxxPreexistingThreadExceptionScenario    |
      | CxxRethrowExceptionScenario              |

  Scenario: Inspecting the exception does not overwrite its stack trace
    When I run "CxxInspectingExceptionScenario" and relaunch the crashed app
    And I configure Bugsnag for "CxxInspectingExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "16CxxTestException"
    And the exception "message" equals "Original exception message"
    And the "method" of stack frame 0 equals "-[CxxInspectingExceptionScenario crash]"
    And the event "unhandled" is true

  Scenario Outline: Throwing without an active exception
    When I run "<scenario>" and relaunch the crashed app
    And I configure Bugsnag for "<scenario>"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "std::terminate"
    And the exception "message" equals "throw may have been called without an exception"
    And the error payload field "events.0.exceptions.0.stacktrace.0.method" does not equal "__cxa_throw_decorator"
    And the "method" of stack frame 2 equals "-[CxxBareThrowScenario run]"
    And on iOS 12 and later, the event "threads.0.name" equals "œ´¨ø“‘"
    And on macOS 10.14 and later, the event "threads.0.name" equals "œ´¨ø“‘"

    Examples:
      | scenario                       |
      | CxxBareThrowScenario            |
      | CxxBareThrowAfterCatchScenario  |
