Feature: Discarding reports based on release stage

  Background:
    Given I clear all persistent data

  Scenario: Unhandled error ignored when release stage is not present in enabledReleaseStages
    When I run "UnhandledErrorInvalidReleaseStage" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorInvalidReleaseStage"
    Then I should receive no requests

  Scenario: Unhandled error captured when release stage is present in enabledReleaseStages
    When I run "UnhandledErrorValidReleaseStage" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorValidReleaseStage"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the event "unhandled" is true
    And the event "app.releaseStage" equals "prod"

  Scenario: Crash when release stage is changed to not present in enabledReleaseStages before the event
  If the current run has a different release stage than the crashing context,
  the report should only be sent if the release stage was in enabledReleaseStages
  at the time of the crash. Release stages can change for a single build of an app
  if the app is used as a test harness or if the build can receive code updates,
  such as JavaScript execution contexts.

    When I run "UnhandledErrorChangeInvalidReleaseStage" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorChangeInvalidReleaseStage"
    Then I should receive no requests

  Scenario: Crash when release stage is changed to be present in enabledReleaseStages before the event
    When I run "UnhandledErrorChangeValidReleaseStage" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorChangeValidReleaseStage"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the event "unhandled" is true
    And the event "app.releaseStage" equals "prod"

  Scenario: Handled error when release stage is not present in enabledReleaseStages
    When I run "HandledErrorInvalidReleaseStage"
    And I configure Bugsnag for "HandledErrorInvalidReleaseStage"
    Then I should receive no requests

  Scenario: Handled error when release stage is present in enabledReleaseStages
    When I run "HandledErrorValidReleaseStage"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals the platform-dependent string:
      | ios   | iOSTestApp.MagicError   |
      | macos | macOSTestApp.MagicError |
    And the exception "message" equals "incoming!"
    And the event "unhandled" is false
    And the event "app.releaseStage" equals "prod"
