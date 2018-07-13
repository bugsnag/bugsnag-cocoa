Feature: Session Tracking

Scenario: Launching using the default configuration sends a single session
    When I run "AutoSessionScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element
    And the session "id" is not null
    And the session "startedAt" is not null
    And the session "user.id" is null
    And the session "user.email" is null
    And the session "user.name" is null

Scenario: Configuring user info sends it with auto-captured sessions
    When I run "AutoSessionWithUserScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element
    And the session "id" is not null
    And the session "user.id" equals "123"
    And the session "user.email" equals "joe@example.com"
    And the session "user.name" equals "Joe Bloggs"

Scenario: Configuring user info sends it with manually captured sessions
    When I run "ManualSessionWithUserScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element
    And the session "id" is not null
    And the session "user.id" equals "123"
    And the session "user.email" equals "joe@example.com"
    And the session "user.name" equals "Joe Bloggs"

Scenario: Disabling auto-capture and calling startSession() manually sends a single session
    When I run "ManualSessionScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element
    And the session "id" is not null
    And the session "startedAt" is not null
    And the session "user.id" is null
    And the session "user.email" is null
    And the session "user.name" is null

Scenario: Disabling auto-capture sends no sessions
    When I run "DisabledSessionTrackingScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive 0 requests

Scenario: Encountering a handled event during a session
    When I run "AutoSessionHandledEventsScenario" with the defaults on "iPhone8-11.2"
    And I wait for 10 seconds
    Then I should receive 3 requests
    And request 0 is valid for the session tracking API
    And request 1 is valid for the error reporting API
    And request 2 is valid for the error reporting API

    And the payload field "events" is an array with 1 element for request 1
    And the payload field "events.0.session.events.handled" equals 1 for request 1
    And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0

    And the payload field "events" is an array with 1 element for request 2
    And the payload field "events.0.session.events.handled" equals 2 for request 2
    And the payload field "events.0.session.id" of request 2 equals the payload field "sessions.0.id" of request 0
