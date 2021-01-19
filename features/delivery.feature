Feature: Delivery of errors

  Background:
    Given I clear all persistent data

  Scenario: Delivery is retried after an HTTP 500 error
    When I set the HTTP status code for the next request to 500
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier

  Scenario: Delivery is not retried after an HTTP 400 error
    When I set the HTTP status code for the next request to 400
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    Then I should receive no requests
