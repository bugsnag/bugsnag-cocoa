Feature: Session Tracking

Scenario: Automatic Session Tracking sends
    When I run "AutoSessionScenario" with the defaults on "iPhone8-11.2"
    And I wait for 5 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element

    # N.B. user.id is null by default if not configured by the developer.
    And the session "user.id" is null
    And the session "id" is not null
    And the session "startedAt" is not null

Scenario: Manual Session sends
    When I run "ManualSessionScenario" with the defaults on "iPhone8-11.2"
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "sessions" is an array with 1 element
    And the session "user.id" equals "123"
    And the session "user.email" equals "user@example.com"
    And the session "user.name" equals "Joe Bloggs"
    And the session "id" is not null
    And the session "startedAt" is not null

Scenario: Disabled Session Tracking sends no requests
    When I run "DisabledSessionTrackingScenario" with the defaults on "iPhone8-11.2"
    And I wait for 5 seconds
    Then I should receive 0 requests
