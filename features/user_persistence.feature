Feature: Persisting User Information

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

Scenario: User Info is persisted across app runs
    When I run "UserPersistencePersistUserScenario"

    # User is set and comes through 
    And I wait for a request
    Then the request is valid for the session tracking API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"

    # Generate session and event 
    Then I crash the app using "NullPointerScenario"
    And I relaunch the app
    And I wait for 2 requests

    # Session - User persisted
    Then the request 0 is valid for the session tracking API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"

    # Event - User persisted
    And the request 1 is valid for the error reporting API
    And the payload field "events.0.user.id" equals "foo" for request 1
    And the payload field "events.0.user.email" equals "baz@grok.com" for request 1
    And the payload field "events.0.user.name" equals "bar" for request 1

Scenario: User Info is not persisted across app runs
    When I run "UserPersistenceDontPersistUserScenario"
    
    # User is set and comes through    
    And I wait for 2 requests

    # First Session
    Then the request 0 is valid for the session tracking API
    And the session "user.id" equals "john"
    And the session "user.email" equals "george@ringo.com"
    And the session "user.name" equals "paul"
    
    # First Event
    And the request 1 is valid for the error reporting API
    And the payload field "events.0.user.id" equals "john" for request 1
    And the payload field "events.0.user.email" equals "george@ringo.com" for request 1
    And the payload field "events.0.user.name" equals "paul" for request 1

    # Restart app - expect no user

    # This generates an OOM:
    And the app is unexpectedly terminated
    And I run "UserPersistenceNoUserScenario"
    # Events are cumulative, i.e. three more: this is the total this scenario
    And I wait for 5 requests

    # Second Session
    Then the request 2 is valid for the session tracking API
    # Awaiting maze-runner update:
    And the session "user.id" does not equal "john" for request 2
    And the session "user.id" does not equal "foo" for request 2
    And the session "user.email" is null for request 2
    And the session "user.name" is null for request 2

    # Second Event (OOM: id is the non-persisted-but-still-current one from earlier)
    And the request 3 is valid for the error reporting API
    And the payload field "events.0.user.id" equals "john" for request 3
    And the payload field "events.0.user.email" equals "george@ringo.com" for request 3
    And the payload field "events.0.user.name" equals "paul" for request 3

    # Third Event (Manually sent, non-persisted, generated id)
    And the request 4 is valid for the error reporting API
    And the payload field "events.0.user.id" is not null for request 4
    And the payload field "events.0.user.id" does not equal "john" for request 4
    And the payload field "events.0.user.id" does not equal "foo" for request 4
    And the payload field "events.0.user.email" is null for request 4
    And the payload field "events.0.user.name" is null for request 4