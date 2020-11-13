Feature: The context can be automatically and manually set on errors

  Background:
    Given I clear all persistent data

  Scenario: Automatic context from a handled NSError
    When I run "AutoContextNSErrorScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" equals "AutoContextNSErrorScenario (100)"

  Scenario: Automatic context from a handled NSException
    When I run "AutoContextNSExceptionScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" is null

  Scenario: Automatic context from a C error
    When I run "AbortScenario" and relaunch the app
    And I configure Bugsnag for "AbortScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" is null

  Scenario: Manual context from Configuration
    When I run "ManualContextConfigurationScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" equals "contextFromConfig"

  Scenario: Manual context from Client
    When I run "ManualContextClientScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" equals "contextFromClient"

  Scenario: Manual context from an OnError callback
    When I run "ManualContextOnErrorScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "context" equals "OnErrorContext"
