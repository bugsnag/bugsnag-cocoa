Feature: Minimal Crash report
    "Minimal" crash reports are generated when an error condition occurs
    while a crash is already being handled. Minimal reports include basic
    app and device metadata while skipping the more complex parts of reports,
    like breadcrumbs and custom post-crash handlers.

Scenario: Crash within the crash handler
    When I run "MinimalCrashReportScenario" and relaunch the app
    And I configure Bugsnag for "MinimalCrashReportScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the payload field "events" is an array with 2 elements
    And the payload field "events.0.unhandled" is true
    And the payload field "events.1.unhandled" is true
    And each event in the payload matches one of:
        | exceptions.0.errorClass | severity |
        | SIGABRT                 | error    |
        | NSGenericException      | error    |
