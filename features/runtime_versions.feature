Feature: Runtime versions are included in all requests

  Background:
    Given I clear all persistent data

  Scenario: Runtime versions included in Cocoa error
    When I run "HandledErrorScenario"
    And I wait to receive an error
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
    And the payload field "events.0.device.runtimeVersions.clangVersion" is not null

  Scenario: Runtime versions included in Cocoa session
    When I run "ManualSessionScenario"
    And I wait to receive a session
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "device.runtimeVersions.osBuild" is not null
    And the session payload field "device.runtimeVersions.clangVersion" is not null

  Scenario: Runtime versions included in C layer ThrownErrorScenario
    And I run "CxxExceptionScenario" and relaunch the app
    And I configure Bugsnag for "CxxExceptionScenario"
    And I wait to receive an error
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
