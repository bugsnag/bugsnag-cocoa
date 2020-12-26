Feature: Discarding sessions based on release stage

  Background:
    Given I clear all persistent data

  Scenario: Automatic sessions are only sent when enabledReleaseStages contains the releaseStage
    When I run "EnabledReleaseStageAutoSessionScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

    And I relaunch the app
    And I configure Bugsnag for "DisabledReleaseStageAutoSessionScenario"
    Then I should receive no errors

  Scenario: Manual sessions are only sent when enabledReleaseStages contains the releaseStage
    When I run "EnabledReleaseStageManualSessionScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

    And I relaunch the app
    And I configure Bugsnag for "DisabledReleaseStageManualSessionScenario"
    Then I should receive no errors
