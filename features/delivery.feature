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
    Then the error is valid for the error reporting API

  Scenario: Delivery is not retried after an HTTP 400 error
    When I set the HTTP status code for the next request to 400
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    Then I should receive no requests

  Scenario: Bugsnag.start() should block for 2 seconds after a launch crash
    When I run "SendLaunchCrashesSynchronouslyScenario" and relaunch the app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 2.0 and 2.5

  Scenario: Bugsnag.start() should not block if sendLaunchCrashesSynchronously is false
    When I run "SendLaunchCrashesSynchronouslyFalseScenario" and relaunch the app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyFalseScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5

  Scenario: Bugsnag.start() should not block for non-launch crashes
    When I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario" and relaunch the app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5
