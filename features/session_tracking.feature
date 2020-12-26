Feature: Session Tracking

  Background:
    Given I clear all persistent data

  Scenario: Launching using the default configuration sends a single session
    When I run "AutoSessionScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "app.version" equals "1.0.3"
    And the session payload field "app.bundleVersion" equals "5"
    And the session payload field "app.releaseStage" equals "development"
    And the session payload field "app.type" equals "iOS"
    And the session payload field "device.osName" equals "iOS"
    And the session payload field "device.model" matches the test device model

    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    And the session "user.id" is not null
    And the session "user.email" is null
    And the session "user.name" is null

  Scenario: Configuring a custom version sends it in a session request
    When I run "AutoSessionCustomVersionScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "app.version" equals "2.0.14"
    And the session payload field "app.bundleVersion" equals "5"
    And the session payload field "app.releaseStage" equals "development"
    And the session payload field "app.type" equals "iOS"
    And the session payload field "device.osName" equals "iOS"
    And the session payload field "device.model" matches the test device model

    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    And the session "user.id" is not null
    And the session "user.email" is null
    And the session "user.name" is null

  Scenario: Configuring user info sends it with auto-captured sessions
    When I run "AutoSessionWithUserScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    And the session "user.id" equals "123"
    And the session "user.email" equals "joe@example.com"
    And the session "user.name" equals "Joe Bloggs"

  Scenario: Configuring user info sends it with manually captured sessions
    When I run "ManualSessionWithUserScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    And the session "user.id" equals "123"
    And the session "user.email" equals "joe@example.com"
    And the session "user.name" equals "Joe Bloggs"

  Scenario: Disabling auto-capture and calling startSession() manually sends a single session
    When I run "ManualSessionScenario"
    And I wait to receive a session
    And the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    # This behaviour isn't established yet
    # And the session "user.id" is null
    # And the session "user.email" is null
    # And the session "user.name" is null

  Scenario: Disabling auto-capture sends no sessions
    When I run "DisabledSessionTrackingScenario"
    And I wait for 3 seconds
    Then I should receive no errors
    And I should receive no sessions

  Scenario: Encountering a handled event during a session
    When I run "AutoSessionHandledEventsScenario"
    And I wait to receive a session
    And I wait to receive 2 errors
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "sessions.0.id" is stored as the value "session_id"

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the payload field "events.0.session.events.handled" equals 1
    And the payload field "events.0.session.id" equals the stored value "session_id"
    And I discard the oldest error

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the payload field "events.0.session.events.handled" equals 2
    And the payload field "events.0.session.id" equals the stored value "session_id"

  Scenario: Encountering an unhandled event during a session
    When I run "AutoSessionUnhandledScenario"
    And I wait for 4 seconds
    And I relaunch the app
    And I set the app to "noevent" mode
    And I configure Bugsnag for "AutoSessionUnhandledScenario"
    And I wait to receive a session
    And I wait to receive an error
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "sessions" is an array with 1 elements
    And the session payload field "sessions.0.id" is a UUID
    And the session payload field "sessions.0.startedAt" is a parsable timestamp in seconds
    And the session payload field "sessions.0.id" is stored as the value "session_id"

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the payload field "events.0.session.events.handled" equals 0
    And the payload field "events.0.session.events.unhandled" equals 1
    And the payload field "events.0.session.id" equals the stored value "session_id"

  Scenario: Encountering handled and unhandled events during a session
    When I run "AutoSessionMixedEventsScenario"
    And I wait for 5 seconds
    And I relaunch the app
    And I configure Bugsnag for "AutoSessionMixedEventsScenario"
    And I wait to receive 2 sessions
    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
    And the session payload field "sessions" is an array with 1 elements
    And the session "id" is not null
    And the session "startedAt" is not null
    And the session payload field "sessions" is an array with 1 elements
    And I discard the oldest session

    Then the session is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier

    And I wait to receive 3 errors
    Then the received errors match:
        | exceptions.0.errorClass | session.events.handled | session.events.unhandled |
        | FirstErr                | 1                      | 0                        |
        | SecondErr               | 2                      | 0                        |
        | Kaboom                  | 2                      | 1                        |

    And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest error

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest error

    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
