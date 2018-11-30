Feature: Reporting User Information

Scenario: User fields set as null
    When I run "UserDisabledScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the exception "message" equals "The operation couldn’t be completed. (UserDisabledScenario error 100.)"
    And the event "user.id" is not null
    And the event "user.email" is null
    And the event "user.name" is null

Scenario: Only User email field set
    When I run "UserEmailScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserEmailScenario error 100.)"
    And the event "user.id" is not null
    And the event "user.email" equals "user@example.com"
    And the event "user.name" is null

Scenario: All user fields set
    When I run "UserEnabledScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the exception "message" equals "The operation couldn’t be completed. (UserEnabledScenario error 100.)"
    And the event "user.id" equals "123"
    And the event "user.email" equals "user@example.com"
    And the event "user.name" equals "Joe Bloggs"

Scenario: Only User ID field set
    When I run "UserIdScenario"
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "The operation couldn’t be completed. (UserIdScenario error 100.)"
    And the event "user.id" equals "abc"
    And the event "user.email" is null
    And the event "user.name" is null
