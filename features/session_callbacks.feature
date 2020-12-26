Feature: Callbacks can access and modify session information

  Background:
    Given I clear all persistent data

  Scenario: Returning false in a callback discards sessions
    When I run "SessionCallbackDiscardScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

  Scenario: Callbacks execute in the order in which they were added
    When I run "SessionCallbackOrderScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "app.id" equals "First callback: 0"
    And the session payload field "device.id" equals "Second callback: 1"

  Scenario: Modifying session information with a callback
    When I run "SessionCallbackOverrideScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "app.id" equals "customAppId"
    And the session payload field "device.id" equals "customDeviceId"
    And the session "user.id" equals "customUserId"

  Scenario: Callbacks can be removed without affecting the functionality of other callbacks
    When I run "SessionCallbackRemovalScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "app.id" equals "customAppId"
    And the session payload field "device.id" equals "customDeviceId"

  Scenario: An uncaught NSException in a callback does not affect session delivery
    When I run "SessionCallbackCrashScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "app.id" equals "customAppId"
    And the session "user.id" equals "placeholderId"
