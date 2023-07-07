Feature: Telemetry

  Background:
    Given I clear all persistent data

  Scenario: An internal error report is sent for invalid KSCrashReport files
    When I run "InvalidCrashReportScenario" and relaunch the crashed app
    And I configure Bugsnag for "InvalidCrashReportScenario"
    And I wait to receive an error
    And the error "Bugsnag-Api-Key" header is not present
    And the error "Bugsnag-Internal-Error" header equals "bugsnag-cocoa"
    And the error payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements
    And the error payload field "events.0.threads" is an array with 0 elements
    And the event "apiKey" is null
    And the event "context" equals "JSON parsing error"
    And the event "metaData.BugsnagDiagnostics.apiKey" equals "12312312312312312312312312312312"
    And the event "metaData.BugsnagDiagnostics.data" is null
    And the event "metaData.BugsnagDiagnostics.keys" is a non-empty array
    And the event "metaData.BugsnagDiagnostics.fileName" matches ".+\.json$"
    And the event "metaData.BugsnagDiagnostics.modificationInterval" is between 1.0 and 2.0
    And the event "unhandled" is false
    And the exception "errorClass" equals "Invalid crash report"
    And the exception "message" matches "NSCocoaErrorDomain 3840: No string key for value in object around .+\."

  Scenario: An internal error report is sent if directories cannot be created
    When I run "CouldNotCreateDirectoryScenario"
    And I wait to receive an error
    And the error "Bugsnag-Api-Key" header is not present
    And the error "Bugsnag-Internal-Error" header equals "bugsnag-cocoa"
    And the error payload field "events.0.exceptions.0.stacktrace" is an array with 0 elements
    And the error payload field "events.0.threads" is an array with 0 elements
    And the event "apiKey" is null
    And the event "context" equals "v1"
    And the event "metaData.BugsnagDiagnostics.apiKey" equals "12312312312312312312312312312312"
    And the event "metaData.BugsnagDiagnostics.NSFilePath" matches "com.bugsnag.Bugsnag"
    And the event "unhandled" is false
    And the exception "errorClass" equals "Could not create directory"
    And the exception "message" matches "NSCocoaErrorDomain 513: You don’t have permission"

  Scenario: Internal errors are not sent if disabled
    When I run "InvalidCrashReportScenario" and relaunch the crashed app
    And I set the app to "internalErrorsDisabled" mode
    And I configure Bugsnag for "InvalidCrashReportScenario"
    Then I should receive no errors

  Scenario: Usage telemetry is not send if disabled
    When I run "TelemetryUsageDisabledScenario"
    And I wait to receive an error
    Then the event "usage" is null
