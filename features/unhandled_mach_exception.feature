Feature: Bugsnag captures an unhandled mach exception

  Background:
    Given I clear all UserDefaults data

  Scenario: Trigger a mach exception
    When I run "UnhandledMachExceptionScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledMachExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "exceptions.0.message" equals "Attempted to dereference null pointer."
    And the event "severity" equals "error"
    And the event "unhandled" is true
    And the event "severityReason.type" equals "unhandledException"
