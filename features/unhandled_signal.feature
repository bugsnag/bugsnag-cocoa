Feature: Signals are captured as error reports in Bugsnag

Scenario: Triggering SIGABRT
    When I run "AbortScenario" and relaunch the app
    And I configure Bugsnag for "AbortScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "<redacted>"
    And the "method" of stack frame 2 equals "abort"
    And the "method" of stack frame 3 equals "-[AbortScenario run]"

Scenario: Triggering SIGPIPE
    When I run "SIGPIPEScenario" and relaunch the app
    And I configure Bugsnag for "SIGPIPEScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGPIPE"

Scenario: Triggering SIGBUS
    When I run "SIGBUSScenario" and relaunch the app
    And I configure Bugsnag for "SIGBUSScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGBUS"

Scenario: Triggering SIGFPE
    When I run "SIGFPEScenario" and relaunch the app
    And I configure Bugsnag for "SIGFPEScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGFPE"

Scenario: Triggering SIGILL
    When I run "SIGILLScenario" and relaunch the app
    And I configure Bugsnag for "SIGILLScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGILL"

Scenario: Triggering SIGSEGV
    When I run "SIGSEGVScenario" and relaunch the app
    And I configure Bugsnag for "SIGSEGVScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGSEGV"

Scenario: Triggering SIGSYS
    When I run "SIGSYSScenario" and relaunch the app
    And I configure Bugsnag for "SIGSYSScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGSYS"

Scenario: Triggering SIGTRAP
    When I run "SIGTRAPScenario" and relaunch the app
    And I configure Bugsnag for "SIGTRAPScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 1 elements
    And the exception "errorClass" equals "SIGTRAP"
