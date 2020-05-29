Feature: Enabled error types

Scenario: All Crash reporting is disabled
    # Sessions: on, unhandled crashes: off
    When I run "DisableAllExceptManualExceptionsAndCrashScenario" and relaunch the app
    And I configure Bugsnag for "DisableAllExceptManualExceptionsAndCrashScenario"
    And I wait to receive 2 requests
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

Scenario: All Crash reporting is disabled but manual notification works
    # enabledErrorTypes = None, Generate a manual notification, crash
    When I run "DisableAllExceptManualExceptionsSendManualAndCrashScenario" and relaunch the app
    And I configure Bugsnag for "DisableAllExceptManualExceptionsSendManualAndCrashScenario"

    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier

Scenario: NSException Crash Reporting is disabled
    When I run "DisableNSExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DisableNSExceptionScenario"

    # This received request is confirmation the scenario is running through
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "unhandled" is false
    And the payload field "events.0.exceptions.0.message" equals "DisableNSExceptionScenario - Handled"

Scenario: CPP Crash Reporting is disabled
    When I run "EnabledErrorTypesCxxScenario" and relaunch the app
    And I configure Bugsnag for "EnabledErrorTypesCxxScenario"
    And I wait to receive 2 requests
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

Scenario: Mach Crash Reporting is disabled
    When I run "DisableMachExceptionScenario"
    And I relaunch the app
    And I configure Bugsnag for "DisableMachExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "unhandled" is false
    And the payload field "events.0.exceptions.0.message" equals "DisableMachExceptionScenario - Handled"

Scenario: Signals Crash Reporting is disabled
    When I run "DisableSignalsExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DisableSignalsExceptionScenario"
    And I wait for 5 seconds
    And I should receive no requests
