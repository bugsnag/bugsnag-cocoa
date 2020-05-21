Feature: Modifying configuration settings after start() is called
    In some cases, such as within opt-in/opt-out flows, the configuration
    of the library should be allowed to be changed to reflect user preferences.

    Background:
        Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

    # autoTracksessions is on by default.  Turning it on in config before crashing 
    # should not cause the event to be sent.
    Scenario: Turning on crash detection after start()
        When I crash the app using "TurnOnCrashDetectionAfterStartScenario"
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    # autoTracksessions is on by default.  Turning it off in config before crashing 
    # should not stop the event being sent.
    Scenario: Turning off crash detection after start()
        When I crash the app using "TurnOffCrashDetectionAfterStartScenario"
        And I relaunch the app
        And I wait for a request
        Then the request is valid for the error reporting API
        And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
        And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
        And the payload field "events" is an array with 1 element
        And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
        And the "method" of stack frame 0 equals "-[TurnOffCrashDetectionAfterStartScenario run]"
        And I wait for 10 seconds
        Then I should receive 1 request
