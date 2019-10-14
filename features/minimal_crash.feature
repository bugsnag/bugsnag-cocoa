Feature: Minimal Crash report
    "Minimal" crash reports are generated when an error condition occurs
    while a crash is already being handled. Minimal reports include basic
    app and device metadata while skipping the more complex parts of reports,
    like breadcrumbs and custom post-crash handlers.

Scenario: Crash within the crash handler
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "MinimalCrashReportScenario"
    And I relaunch the app
    And I wait for 2 requests
    And the request 0 is valid for the error reporting API
    And the request 1 is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa" for request 0
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa" for request 1
    And the payload field "events.0.unhandled" is true for request 0
    And the payload field "events.0.unhandled" is true for request 1
    And the request 0 matches one of:
        | exceptions.0.errorClass | severity |
        | SIGABRT                 | error    |
        | NSGenericException      | error    |
    And the request 1 matches one of:
        | exceptions.0.errorClass | severity |
        | SIGABRT                 | error    |
        | NSGenericException      | error    |
