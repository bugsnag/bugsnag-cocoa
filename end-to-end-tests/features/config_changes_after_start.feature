Feature: Modifying configuration settings after start() is called
    In some cases, such as within opt-in/opt-out flows, the configuration
    of the library should be allowed to be changed to reflect user preferences.

    Scenario: Turning on crash detection after start()
        When I run "TurnOnCrashDetectionAfterStartScenario" and relaunch the app
        And I configure Bugsnag for "TurnOnCrashDetectionAfterStartScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
        And the "method" of stack frame 0 equals "-[TurnOnCrashDetectionAfterStartScenario run]"

    Scenario: Turning off crash detection after start()
        When I run "TurnOffCrashDetectionAfterStartScenario" and relaunch the app
        And I configure Bugsnag for "TurnOffCrashDetectionAfterStartScenario"
        And I wait for 10 seconds
        Then I should receive no requests
