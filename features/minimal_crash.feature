Feature: Minimal Crash report
    "Minimal" crash reports are generated when an error condition occurs
    while a crash is already being handled. Minimal reports include basic
    app and device metadata while skipping the more complex parts of reports,
    like breadcrumbs and custom post-crash handlers.

Scenario: Crash within the crash handler
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "MinimalCrashReportScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload body matches the JSON fixture in "features/fixtures/json/minimal-crash-ios.json"
