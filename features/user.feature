Feature: Reporting User Information

  Background:
    Given I clear all persistent data

  Scenario: Default and set user information
    When I run "UserInfoScenario"
    And I wait to receive 4 errors
    Then the error is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserDefaultInfo error 100.)"
    And the event "user.id" is not null
    And the event "user.email" is null
    And the event "user.name" is null
    And I discard the oldest error

    # User fields set as null
    Then the error is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserDisabled error 100.)"
    And the error payload field "events.0.device.id" is stored as the value "device_id"
    And the error payload field "events.0.user.id" equals the stored value "device_id"
    And the event "user.email" is null
    And the event "user.name" is null
    And I discard the oldest error

    # Only User email field set
    Then the error is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserEmail error 100.)"
    And the error payload field "events.0.user.id" equals the stored value "device_id"
    And the event "user.email" equals "user@example.com"
    And the event "user.name" is null
    And I discard the oldest error

    # All user fields set
    Then the error is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserEnabled error 100.)"
    And the event "user.id" equals "123"
    And the event "user.email" equals "user2@example.com"
    And the event "user.name" equals "Joe Bloggs"

  Scenario: Overriding the user in error and session callbacks
    When I run "UserSessionOverrideScenario"
    And I wait to receive a session
    And I wait to receive an error
    Then the session is valid for the session reporting API
    And the session "user.id" equals "sessionCustomId"
    And the session "user.email" equals "sessionCustomEmail"
    And the session "user.name" equals "sessionCustomName"

    And the error is valid for the error reporting API
    And the event "user.id" equals "errorCustomId"
    And the event "user.email" equals "errorCustomEmail"
    And the event "user.name" equals "errorCustomName"

  Scenario: Setting the user from Configuration for a session
    When I run "UserFromConfigScenario"
    And I wait to receive a session
    And I wait to receive an error
    Then the session is valid for the session reporting API
    And the session "user.id" equals "abc"
    And the session "user.email" equals "fake@gmail.com"
    And the session "user.name" equals "Fay K"

    Then the error is valid for the error reporting API
    And the event "user.id" equals "abc"
    And the event "user.email" equals "fake@gmail.com"
    And the event "user.name" equals "Fay K"
    And the event "metaData.clientUserValue.id" equals "abc"
    And the event "metaData.clientUserValue.email" equals "fake@gmail.com"
    And the event "metaData.clientUserValue.name" equals "Fay K"

  Scenario: Setting the user from Client for sessions
    When I run "UserFromClientScenario"
    And I wait to receive a session
    Then the session is valid for the session reporting API
    And the session "user.id" equals "def"
    And the session "user.email" equals "sue@gmail.com"
    And the session "user.name" equals "Sue"

  Scenario: Setting the user ID to nil
    When I run "UserNilScenario"
    And I wait to receive 2 sessions
    Then the received sessions match:
      | user.id   | user.email | user.name |
      | @not_null | null       | null      |
      | null      | null       | null      |
    And I wait to receive an error
    And the event "user.id" is null
    And the event "user.email" is null
    And the event "user.name" is null
