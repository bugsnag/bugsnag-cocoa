Feature: Persisting User Information

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

Scenario: User Info is persisted across app runs
    When I run "UserPersistencePersistUserScenario"
    And I wait for a request
    Then the request is valid for the session tracking API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"
    Then I crash the app using "NullPointerScenario"
    
    And I relaunch the app
    And I wait for 2 requests
    Then the request 0 is valid for the session tracking API
    And the request 1 is valid for the error reporting API
    And the session "user.id" equals "foo"
    And the session "user.email" equals "baz@grok.com"
    And the session "user.name" equals "bar"

    And the payload field "events.0.user.id" equals "foo" for request 1
    And the payload field "events.0.user.email" equals "baz@grok.com" for request 1
    And the payload field "events.0.user.name" equals "bar" for request 1

Scenario: User Info is not persisted across app runs
    When I run "UserPersistenceDontPersistUserScenario"
    And I wait for a request
    Then the request is valid for the session tracking API
    And the session "user.id" equals "john"
    And the session "user.email" equals "george@ringo.com"
    And the session "user.name" equals "paul"
    Then I crash the app using "NullPointerScenario"
    
    And I relaunch the app
    And I run "UserPersistenceNoUserScenario"
    # Session, Session, Event 
    And I wait for 3 requests
    Then the request 0 is valid for the session tracking API
    And the request 1 is valid for the session tracking API
    And the request 2 is valid for the error reporting API
    And the payload field "events.0.user.id" is not null for request 2
    # id is arbitrary
    And the payload field "events.0.user.id" does not equal "john" for request 2
    And the payload field "events.0.user.id" does not equal "foo" for request 2
    And the payload field "events.0.user.email" is null for request 2
    And the payload field "events.0.user.name" is null for request 2
