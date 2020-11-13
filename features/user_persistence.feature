Feature: Persisting User Information

  Background:
    Given I clear all persistent data

  Scenario: User Info is persisted from config across app runs
    When I run "UserPersistencePersistUserScenario"

    # User is set and comes through
    And I wait to receive a request
    And I relaunch the app
    Then the request is valid for the session reporting API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"
    And I discard the oldest request

    # Generate session and event
    Then I run "UserPersistenceNoUserScenario"
    And I wait to receive 2 requests
    And I relaunch the app

    # Session - User persisted
    Then the request is valid for the session reporting API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"
    And I discard the oldest request

    # Event - User persisted
    Then the request is valid for the error reporting API
    And the payload field "events.0.user.id" equals "foo"
    And the payload field "events.0.user.email" equals "baz@grok.com"
    And the payload field "events.0.user.name" equals "bar"

Scenario: User Info is persisted from client across app runs
    When I run "UserPersistencePersistUserClientScenario"

    # Session is captured before the user can be set on the Client
    And I wait to receive a request
    And I relaunch the app
    Then the request is valid for the session reporting API
    And the session "user.id" is not null
    And the session "user.email" is null
    And the session "user.name" is null
    And I discard the oldest request

    # Generate session and event
    Then I run "UserPersistenceNoUserScenario"
    And I wait to receive 2 requests
    And I relaunch the app

    # Session - User persisted
    Then the request is valid for the session reporting API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"
    And I discard the oldest request

    # Event - User persisted
    Then the request is valid for the error reporting API
    And the payload field "events.0.user.id" equals "foo"
    And the payload field "events.0.user.email" equals "baz@grok.com"
    And the payload field "events.0.user.name" equals "bar"


  Scenario: User Info is not persisted across app runs
    When I run "UserPersistenceDontPersistUserScenario"

    # User is set and comes through
    And I wait to receive 2 requests
    And I relaunch the app

    # First Session
    Then the request is valid for the session reporting API
    And the session "user.id" equals "john"
    And the session "user.email" equals "george@ringo.com"
    And the session "user.name" equals "paul"
    And I discard the oldest request

    # First Event
    Then the request is valid for the error reporting API
    And the payload field "events.0.user.id" equals "john"
    And the payload field "events.0.user.email" equals "george@ringo.com"
    And the payload field "events.0.user.name" equals "paul"
    And I discard the oldest request

    # Restart app - expect no user
    When I run "UserPersistenceNoUserScenario"
    And I wait to receive 2 requests

    # Second Session
    Then the request is valid for the session reporting API
    And the session "user.id" does not equal "john"
    And the session "user.id" does not equal "foo"
    And the session "user.email" is null
    And the session "user.name" is null
    And I discard the oldest request

    # Third Event (Manually sent, non-persisted, generated id)
    Then the request is valid for the error reporting API
    And the payload field "events.0.user.id" is not null
    And the payload field "events.0.user.id" does not equal "john"
    And the payload field "events.0.user.id" does not equal "foo"
    And the payload field "events.0.user.email" is null
    And the payload field "events.0.user.name" is null
