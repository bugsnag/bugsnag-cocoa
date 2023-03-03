Feature: Starting Bugsnag

    Background:
        Given I clear all persistent data

    Scenario: Is started is true
        When I run "IsStartedScenario"
        And I wait to receive a session
        And I should receive no errors

    Scenario: Is started is false before Bugsnag.start() is called
        When I run "IsNotStartedScenario"
        And I wait to receive a session
        And I should receive no errors
