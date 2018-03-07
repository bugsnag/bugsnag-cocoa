Feature: Handled Error

Scenario: Handled Error report override
    When I run "HandledErrorOverrideScenario" with the defaults
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "Bar"
    And the exception "message" equals "Foo"

Scenario: Handled Error delivered
    When I run "HandledErrorScenario" with the defaults
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "NSError"
    And the exception "message" equals "The operation couldn’t be completed. (HandledErrorScenario error 100.)"

Scenario: Handled Exception delivered
    When I run "HandledExceptionScenario" with the defaults
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "HandledExceptionScenario"
    And the exception "message" equals "Message: HandledExceptionScenario"
