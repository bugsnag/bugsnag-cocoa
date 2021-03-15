Feature: Enabled error types

  Background:
    Given I clear all persistent data

  Scenario: All Crash reporting is disabled
    # enabledErrorTypes = None, Generate a manual notification, crash
    When I run "DisableAllExceptManualExceptionsAndCrashScenario" and relaunch the app
    And I configure Bugsnag for "DisableAllExceptManualExceptionsAndCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false

  Scenario: NSException Crash Reporting is disabled
    When I run "DisableNSExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DisableNSExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    # Default NSException handler calls abort()
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: CPP Crash Reporting is disabled
    When I run "EnabledErrorTypesCxxScenario" and relaunch the app
    And I configure Bugsnag for "EnabledErrorTypesCxxScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false

  Scenario: Mach Crash Reporting is disabled
    When I run "DisableMachExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DisableMachExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false

  Scenario: Signals Crash Reporting is disabled
    When I run "DisableSignalsExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DisableSignalsExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
