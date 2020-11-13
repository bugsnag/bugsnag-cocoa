Feature: autoDetectErrors flag controls whether errors are captured automatically
    Bugsnag captures several error types by default. If the autoDetectErrors flag
    is false it should only capture handled errors which the user has reported.

    Background:
        Given I clear all persistent data

    Scenario: Uncaught NSException not reported when autoDetectErrors is false
        When I run "AutoDetectFalseHandledScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API
        And the payload field "events" is an array with 1 elements
        And the event "unhandled" is false
        And I discard the oldest request
        When I run "AutoDetectFalseNSExceptionScenario" and relaunch the app
        And I configure Bugsnag for "AutoDetectFalseHandledScenario"
        Then I should receive no requests

    Scenario: Signal not reported when autoDetectErrors is false
        When I run "AutoDetectFalseHandledScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API
        And the payload field "events" is an array with 1 elements
        And the event "unhandled" is false
        And I discard the oldest request
        When I run "AutoDetectFalseAbortScenario" and relaunch the app
        And I configure Bugsnag for "AutoDetectFalseHandledScenario"
        Then I should receive no requests
