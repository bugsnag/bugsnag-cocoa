Feature: Internal error reporting

  Background:
    Given I clear all persistent data

  Scenario: An internal error report is sent for invalid KSCrashReport files
    When I run "InvalidCrashReportScenario" and relaunch the crashed app
    And I configure Bugsnag for "InvalidCrashReportScenario"
    And I wait to receive an error
    And the error "Bugsnag-Api-Key" header is null
    And the error "Bugsnag-Internal-Error" header equals "bugsnag-cocoa"
    And the error payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements
    And the error payload field "events.0.threads" is an array with 0 elements
    And the event "apiKey" is null
    And the event "groupingHash" equals "BSGEventUploadKSCrashReportOperation.m: JSON parsing error: NSCocoaErrorDomain 3840: No string key for value in object"
    And the event "metaData.BugsnagDiagnostics.apiKey" equals "12312312312312312312312312312312"
    And the event "metaData.BugsnagDiagnostics.data" is not null
    And the event "metaData.BugsnagDiagnostics.file" is not null
    And the event "metaData.BugsnagDiagnostics.modificationInterval" is between 1.0 and 2.0
    And the event "unhandled" is false
    And the exception "errorClass" equals "JSON parsing error"
    And the exception "message" matches "NSCocoaErrorDomain 3840: No string key for value in object around .+\."

  Scenario: Internal errors are not sent if disabled
    When I run "InvalidCrashReportScenario" and relaunch the crashed app
    And I set the app to "internalErrorsDisabled" mode
    And I configure Bugsnag for "InvalidCrashReportScenario"
    Then I should receive no requests
