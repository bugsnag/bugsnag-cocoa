Feature: Bugsnag captures an unhandled mach exception

Scenario: Trigger a mach exception
    When I run "UnhandledMachExceptionScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledMachExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "exceptions.0.message" equals "UnhandledMachExceptionScenario"
