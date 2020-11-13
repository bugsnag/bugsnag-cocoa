Feature: Reporting User Information

  Background:
    Given I clear all persistent data

  Scenario: Default user information only includes ID
    When I run "UserDefaultInfoScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserDefaultInfoScenario error 100.)"
    And the event "user.id" is not null
    And the event "user.email" is null
    And the event "user.name" is null

  Scenario: User fields set as null
    When I run "UserDisabledScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserDisabledScenario error 100.)"
    And the event "user.id" is null
    And the event "user.email" is null
    And the event "user.name" is null

  Scenario: Only User email field set
    When I run "UserEmailScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserEmailScenario error 100.)"
    And the event "user.id" is null
    And the event "user.email" equals "user@example.com"
    And the event "user.name" is null

  Scenario: All user fields set
    When I run "UserEnabledScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserEnabledScenario error 100.)"
    And the event "user.id" equals "123"
    And the event "user.email" equals "user@example.com"
    And the event "user.name" equals "Joe Bloggs"

  Scenario: Only User ID field set
    When I run "UserIdScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserIdScenario error 100.)"
    And the event "user.id" equals "abc"
    And the event "user.email" is null
    And the event "user.name" is null

  Scenario: Overriding the user in the Event callback
    When I run "UserEventOverrideScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "user.id" equals "customId"
    And the event "user.email" equals "customEmail"
    And the event "user.name" equals "customName"

  Scenario: Overriding the user in the Session callback
    When I run "UserSessionOverrideScenario"
    And I wait to receive a request
    Then the request is valid for the session reporting API
    And the session "user.id" equals "customId"
    And the session "user.email" equals "customEmail"
    And the session "user.name" equals "customName"

  Scenario: Setting the user from Configuration for an event
    When I run "UserFromConfigEventScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "user.id" equals "abc"
    And the event "user.email" equals "fake@gmail.com"
    And the event "user.name" equals "Fay K"
    And the event "metaData.clientUserValue.id" equals "abc"
    And the event "metaData.clientUserValue.email" equals "fake@gmail.com"
    And the event "metaData.clientUserValue.name" equals "Fay K"

  Scenario: Setting the user from Configuration for a session
    When I run "UserFromConfigSessionScenario"
    And I wait to receive a request
    Then the request is valid for the session reporting API
    And the session "user.id" equals "abc"
    And the session "user.email" equals "fake@gmail.com"
    And the session "user.name" equals "Fay K"

  Scenario: Setting the user from Client for sessions
    When I run "UserFromClientScenario"
    And I wait to receive a request
    Then the request is valid for the session reporting API
    And the session "user.id" equals "def"
    And the session "user.email" equals "sue@gmail.com"
    And the session "user.name" equals "Sue"
