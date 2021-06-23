Feature: Internal error reporting

  Background:
    Given I clear all persistent data

  Scenario: An internal error report is sent for invalid KSCrashReport files
    When I run "InternalErrorReportingScenarios_KSCrashReport" and relaunch the app
    And I configure Bugsnag for "InternalErrorReportingScenarios_KSCrashReport"
    And I wait to receive an error
    And the error "Bugsnag-Api-Key" header is null
    And the error "Bugsnag-Internal-Error" header equals "bugsnag-cocoa"
    And the error payload field "events.0.threads" is an array with 0 elements
    And the event "apiKey" is null
    And the event "groupingHash" equals "BSGEventUploadKSCrashReportOperation.m: JSON parsing error: NSCocoaErrorDomain 3840: No string key for value in object"
    And the event "metaData.BugsnagDiagnostics.apiKey" equals "12312312312312312312312312312312"
    And the event "metaData.BugsnagDiagnostics.data" is not null
    And the event "unhandled" is false
    And the exception "errorClass" equals "JSON parsing error"
    And the exception "message" matches "NSCocoaErrorDomain 3840: No string key for value in object around character \d+."
