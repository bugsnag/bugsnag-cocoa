Feature: Delivery of errors

  Background:
    Given I clear all persistent data

  Scenario: Delivery is retried after an HTTP 500 error
    When I set the HTTP status code for the next request to 500
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API

  Scenario: Delivery is not retried after an HTTP 400 error
    When I set the HTTP status code for the next request to 400
    And I run "HandledExceptionScenario"
    And I wait to receive an error
    And I kill and relaunch the app
    And I clear the error queue
    And I configure Bugsnag for "HandledExceptionScenario"
    Then I should receive no requests

  Scenario: Bugsnag.start() should block for 2 seconds after a launch crash
    When I run "SendLaunchCrashesSynchronouslyScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 2.0 and 2.5

  Scenario: Bugsnag.start() should not block if sendLaunchCrashesSynchronously is false
    When I run "SendLaunchCrashesSynchronouslyFalseScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyFalseScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5

  Scenario: Bugsnag.start() should not block for non-launch crashes
    When I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario" and relaunch the crashed app
    And I set the response delay for the next request to 5000 milliseconds
    And I set the app to "report" mode
    And I run "SendLaunchCrashesSynchronouslyLaunchCompletedScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And the event "metaData.bugsnag.startDuration" is between 0.0 and 0.5

  Scenario: Session delivery should be retried for recent payloads
    Given I set the HTTP status code for the next request to 500
    And I run "AutoSessionScenario"
    And I wait to receive a session
    And I wait for the fixture to process the response
    And I kill and relaunch the app
    When I run "AutoSessionScenario"
    Then I wait to receive 3 sessions

  Scenario: Session delivery should not be retried for old payloads
    Given I set the HTTP status code for the next request to 500
    And I set the app to "old" mode
    And I run "OldSessionScenario"
    And I wait to receive a session
    And I wait for the fixture to process the response
    And I discard the oldest session
    And I kill and relaunch the app
    When I set the app to "new" mode
    And I run "OldSessionScenario"
    And I wait to receive a session
    Then the session "user.id" equals "new"
    And I discard the oldest session
    And I should receive no requests

  Scenario: The oldest sessions should be deleted to comply with maxPersistedSessions
    Given I set the HTTP status code to 500
    And I run "MaxPersistedSessionsScenario"
    And I wait to receive 2 sessions
    And the session "user.id" equals "1"
    And I discard the oldest session
    And the session "user.id" equals "2"
    And I discard the oldest session
    When I set the HTTP status code to 200
    And I kill and relaunch the app
    And I configure Bugsnag for "MaxPersistedSessionsScenario"
    And I wait to receive 2 sessions
    Then the session "user.id" equals "3"
    And I discard the oldest session
    And the session "user.id" equals "2"
