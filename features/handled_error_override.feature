Feature: Handled Error

Scenario: Handled Error report override
    When I run "HandledErrorOverrideScenario" with the defaults
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "Bar"
    And the exception "message" equals "Foo"
