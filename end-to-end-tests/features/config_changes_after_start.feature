Feature: Modifying configuration settings after start() is called
    In some cases, such as within opt-in/opt-out flows, the configuration
    of the library should be allowed to be changed to reflect user preferences.

    Scenario: Turning on crash detection after start()
        When I run "TurnOnCrashDetectionAfterStartScenario" and relaunch the app
        And I configure Bugsnag for "TurnOnCrashDetectionAfterStartScenario"
        And I wait for a request
        Then the request is valid for the error reporting API
        And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
        And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
        And the payload field "events" is an array with 1 element
        And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
        And the "method" of stack frame 0 equals "-[TurnOnCrashDetectionAfterStartScenario run]"

    Scenario: Turning off crash detection after start()
        When I run "TurnOffCrashDetectionAfterStartScenario" and relaunch the app
        And I configure Bugsnag for "TurnOffCrashDetectionAfterStartScenario"
        And I wait for 10 seconds
        Then I should receive 0 requests
