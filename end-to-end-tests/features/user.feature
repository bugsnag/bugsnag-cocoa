Feature: Reporting User Information

Scenario: User fields set as null
    When I run "UserDisabledScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "The operation couldn’t be completed. (UserDisabledScenario error 100.)"
    And the event "user.id" is not null
    And the event "user.email" is null
    And the event "user.name" is null

Scenario: Only User email field set
    When I run "UserEmailScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "The operation couldn’t be completed. (UserEmailScenario error 100.)"
    And the event "user.id" is not null
    And the event "user.email" equals "user@example.com"
    And the event "user.name" is null

Scenario: All user fields set
    When I run "UserEnabledScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "The operation couldn’t be completed. (UserEnabledScenario error 100.)"
    And the event "user.id" equals "123"
    And the event "user.email" equals "user@example.com"
    And the event "user.name" equals "Joe Bloggs"

Scenario: Only User ID field set
    When I run "UserIdScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the exception "message" equals "The operation couldn’t be completed. (UserIdScenario error 100.)"
    And the event "user.id" equals "abc"
    And the event "user.email" is null
    And the event "user.name" is null
