Feature: Launch detection

  Background:
    Given I clear all persistent data

  Scenario: isLaunching is correct for handled exception during and after launch
    When I run "LaunchDetectionHandledExceptionsScenario"
    And I wait to receive 1 errors
    And the event "app.isLaunching" is true
    And I discard the oldest error
    And I wait to receive 1 errors
    And the event "app.isLaunching" is false

  Scenario: isLaunching should be true if launchDurationMillis is 0
    When I run "InfiniteLaunchDurationScenario"
    And I wait to receive 1 errors
    And the event "app.isLaunching" is true

  Scenario: isLaunching is true for unhandled exception during launch
    When I run "UnhandledExceptionDuringLaunchScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledExceptionDuringLaunchScenario"
    And I wait to receive 1 errors
    And the event "app.isLaunching" is true

  Scenario: isLaunching is false for unhandled exception after launch
    When I run "UnhandledExceptionAfterLaunchScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledExceptionAfterLaunchScenario"
    And I wait to receive 1 errors
    And the event "app.isLaunching" is false
