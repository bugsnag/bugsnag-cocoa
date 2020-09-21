Feature: Bugsnag captures an unhandled mach exception

  Background:
    Given I clear all UserDefaults data

  Scenario: Trigger a mach exception
    When I run "UnhandledMachExceptionScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledMachExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "exceptions.0.errorClass" equals "EXC_BAD_ACCESS"
    And the event "exceptions.0.message" equals "Attempted to dereference garbage pointer 0xdeadbeef."
    And the event "metaData.error.address" equals 3735928559
    And the event "metaData.error.type" equals "mach"
    And the event "metaData.error.mach.code" equals 1
    And the event "metaData.error.mach.code_name" equals "KERN_INVALID_ADDRESS"
    And the event "metaData.error.mach.exception" equals 1
    And the event "metaData.error.mach.exception_name" equals "EXC_BAD_ACCESS"
    And the event "metaData.error.mach.subcode" equals 3735928559
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"
