Feature: Handled Errors and Exceptions

  Background:
    Given I clear all persistent data

  Scenario: Override errorClass and message from a notifyError() callback, customize report

  Discard 2 lines from the stacktrace, as we have single place to report and log errors, see
  https://docs.bugsnag.com/platforms/ios-objc/reporting-handled-exceptions/#depth
  This way top of the stacktrace is not logError but run
  Include configured metadata dictionary into the report

    When I run "HandledErrorOverrideScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "Bar"
    And the exception "message" equals "Foo"
    And the error payload field "events.0.device.time" is a date
    And the event "metaData.account.items.0" equals 400
    And the event "metaData.account.items.1" equals 200
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And the event "severityReason.type" equals "handledError"
    # TODO This may be platform specific:
    # Consider using a step to check for "at least {int} stack frames"
    # And the stack trace is an array with 15 stack frames

  Scenario: Reporting an NSError
    When I run "HandledErrorScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "NSError"
    And the exception "message" equals "The operation couldn’t be completed. (HandledErrorScenario error 100.)"
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And the event "severityReason.type" equals "handledError"
    # TODO This may be platform specific:
    # And the stack trace is an array with 15 stack frames

  Scenario: Reporting a handled exception
    When I run "HandledExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HandledExceptionScenario"
    And the exception "message" equals "Message: HandledExceptionScenario"
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And the event "severityReason.type" equals "handledException"
    # This may be platform specific
    # And the stack trace is an array with 15 stack frames

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

  Scenario: Reporting handled errors concurrently
    When I run "ManyConcurrentNotifyScenario"
    And I wait to receive 8 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | FooError                | Err 0   |
        | FooError                | Err 1   |
        | FooError                | Err 2   |
        | FooError                | Err 3   |
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
    And I discard the oldest error
    Then the error is valid for the error reporting API ignoring breadcrumb timestamps
