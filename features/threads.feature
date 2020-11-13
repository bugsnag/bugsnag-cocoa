Feature: Handled Errors and Exceptions

  Background:
    Given I clear all persistent data

  Scenario: Threads are captured for handled errors by default
    When I run "HandledErrorThreadSendAlwaysScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "unhandled" is false
    And the payload field "events" is an array with 1 elements
    And the exception "message" equals "HandledErrorThreadSendAlwaysScenario"
    And the thread information is valid for the event

  Scenario: Threads are captured for unhandled errors by default
    When I run "UnhandledErrorThreadSendAlwaysScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorThreadSendAlwaysScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "unhandled" is true
    And the payload field "events" is an array with 1 elements
    And the exception "message" equals "UnhandledErrorThreadSendAlwaysScenario"
    And the thread information is valid for the event

  Scenario: Threads are not captured for handled errors when sendThreads is set to unhandled_only
    When I run "HandledErrorThreadSendUnhandledOnlyScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "unhandled" is false
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "HandledErrorThreadSendUnhandledOnlyScenario"
    And the payload field "events.0.threads" is an array with 1 elements
    And the payload field "events.0.threads.0.errorReportingThread" is true
    And the payload field "events.0.threads.0.id" is not null
    And the payload field "events.0.threads.0.name" is null
    And the payload field "events.0.threads.0.type" equals "cocoa"
    And the thread information is valid for the event

  Scenario: Threads are not captured for unhandled errors when sendThreads is set to never
    When I run "UnhandledErrorThreadSendNeverScenario" and relaunch the app
    And I configure Bugsnag for "UnhandledErrorThreadSendNeverScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "unhandled" is true
    And the payload field "events" is an array with 1 elements
    And the exception "message" equals "UnhandledErrorThreadSendNeverScenario"
    And the payload field "events.0.threads" is an array with 1 elements
    And the payload field "events.0.threads.0.errorReportingThread" is true
    And the payload field "events.0.threads.0.id" is not null
    And the payload field "events.0.threads.0.name" is null
    And the payload field "events.0.threads.0.type" equals "cocoa"
    And the thread information is valid for the event
