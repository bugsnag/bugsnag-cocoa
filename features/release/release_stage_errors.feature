Feature: Discarding reports based on release stage

  Background:
    Given I clear all persistent data

  Scenario: Unhandled error ignored when release stage is not present in enabledReleaseStages
    When I run "UnhandledErrorInvalidReleaseStageScenario" and relaunch the crashed app
    And I configure Bugsnag for "UnhandledErrorInvalidReleaseStageScenario"
    Then I should receive no errors

  Scenario: Unhandled error captured when release stage is present in enabledReleaseStages
    When I run "UnhandledErrorValidReleaseStageScenario" and relaunch the crashed app
    And I configure Bugsnag for "UnhandledErrorValidReleaseStageScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the event "unhandled" is true
    And the event "app.releaseStage" equals "prod"

  Scenario: Crash when release stage is changed to not present in enabledReleaseStages before the event
  If the current run has a different release stage than the crashing context,
  the report should only be sent if the release stage was in enabledReleaseStages
  at the time of the crash. Release stages can change for a single build of an app
  if the app is used as a test harness or if the build can receive code updates,
  such as JavaScript execution contexts.

    When I run "UnhandledErrorChangeInvalidReleaseStageScenario" and relaunch the crashed app
    And I configure Bugsnag for "UnhandledErrorChangeInvalidReleaseStageScenario"
    Then I should receive no errors

  Scenario: Crash when release stage is changed to be present in enabledReleaseStages before the event
    When I run "UnhandledErrorChangeValidReleaseStageScenario" and relaunch the crashed app
    And I configure Bugsnag for "UnhandledErrorChangeValidReleaseStageScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the event "unhandled" is true
    And the event "app.releaseStage" equals "prod"

  Scenario: Handled error when release stage is not present in enabledReleaseStages
    When I run "HandledErrorInvalidReleaseStageScenario"
    Then I should receive no errors

  Scenario: Handled error when release stage is present in enabledReleaseStages
    When I run "HandledErrorValidReleaseStageScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" matches the platform-dependent regex:
      | ios   | iOSTestApp(XcFramework)?.MagicError   |
      | macos | macOSTestApp(XcFramework)?.MagicError |
    And the exception "message" equals "incoming!"
    And the event "unhandled" is false
    And the event "app.releaseStage" equals "prod"
