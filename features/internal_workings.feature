Feature: Bugsnag's internal workings

    Background:
        Given I clear all persistent data

    Scenario: Bugsnag library works as it should internally
        When I run "InternalWorkingsScenario"
        And I wait to receive a session
    	And I wait to receive an error
    	And the exception "message" equals "All Clear!"
