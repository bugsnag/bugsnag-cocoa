Feature: autoNotify flag allows disabling error detection after Bugsnag is initialized

    Background:
        Given I clear all persistent data

    Scenario: Uncaught NSException not reported when autoNotify is false
        When I run "AutoNotifyFalseHandledScenario"
        And I wait to receive an error
        Then the error is valid for the error reporting API
        And the error payload field "events" is an array with 1 elements
        And the event "unhandled" is false
        And I discard the oldest error
        And I relaunch the app
        When I run "AutoNotifyFalseNSExceptionScenario" and relaunch the app
        And I configure Bugsnag for "AutoNotifyFalseHandledScenario"
        Then I should receive no requests

    Scenario: Signal not reported when autoNotify is false
        When I run "AutoNotifyFalseHandledScenario"
        And I wait to receive an error
        Then the error is valid for the error reporting API
        And the error payload field "events" is an array with 1 elements
        And the event "unhandled" is false
        And I discard the oldest error
        And I relaunch the app
        When I run "AutoNotifyFalseAbortScenario" and relaunch the app
        And I configure Bugsnag for "AutoNotifyFalseHandledScenario"
        Then I should receive no requests

    Scenario: Uncaught NSException reported when autoDetectErrors set to false then true
        When I run "AutoDetectFalseHandledScenario"
        And I wait to receive an error
        Then the error is valid for the error reporting API
        And the error payload field "events" is an array with 1 elements
        And the event "unhandled" is false
        And I discard the oldest error
        And I relaunch the app
        When I run "AutoNotifyReenabledScenario" and relaunch the app
        And I configure Bugsnag for "AutoNotifyReenabledScenario"
        And I wait to receive an error
        Then the error is valid for the error reporting API
        And the error payload field "events" is an array with 1 elements
        And the event "unhandled" is true
