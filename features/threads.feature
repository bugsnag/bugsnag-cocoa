Feature: Threads

  Background:
    Given I clear all persistent data

  Scenario: Threads are captured for handled errors by default
    When I run "HandledErrorThreadSendAlwaysScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And the error payload field "events" is an array with 1 elements
    And the exception "message" equals "HandledErrorThreadSendAlwaysScenario"
    And the error payload field "events.0.threads" is a non-empty array
    And the error payload field "events.0.threads.1" is not null
    And the thread information is valid for the event

  Scenario: Threads are captured for unhandled errors by default
    When I run "UnhandledErrorThreadSendAlwaysScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorThreadSendAlwaysScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
    And the error payload field "events" is an array with 1 elements
    And the exception "message" equals "UnhandledErrorThreadSendAlwaysScenario"
    And the error payload field "events.0.threads" is a non-empty array
    And the error payload field "events.0.threads.1" is not null
    And the thread information is valid for the event

  Scenario: Threads are not captured for handled errors when sendThreads is set to unhandled_only
    When I run "HandledErrorThreadSendUnhandledOnlyScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And the error payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HandledErrorThreadSendUnhandledOnlyScenario"
    And the error payload field "events.0.threads" is an array with 0 elements

  Scenario: Threads are not captured for unhandled errors when sendThreads is set to never
    When I run "UnhandledErrorThreadSendNeverScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorThreadSendNeverScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
    And the error payload field "events" is an array with 1 elements
    And the exception "message" equals "UnhandledErrorThreadSendNeverScenario"
    And the error payload field "events.0.threads" is an array with 0 elements
