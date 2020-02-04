Feature: Reporting out of memory events
    If the app is terminated without either a reported crash or a "will
    terminate" event, and the underlying OS and app versions remain the same,
    it is likely that the app has been killed.

    Scenario: The OS kills the application in the foreground
        When I run "OOMScenario"
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for a request
        Then the request is valid for the error reporting API
        And the payload field "events" is an array with 1 element
        And the exception "errorClass" equals "Out Of Memory"
        And the exception "message" equals "The app was likely terminated by the operating system while in the foreground"
        And the event "unhandled" is true
        And the event "severity" equals "error"
        And the event "severityReason.type" equals "outOfMemory"
        And the event "app.releaseStage" equals "beta"
        And the event "app.version" equals "1.0.3"
        And the event "app.bundleVersion" equals "5"
        And the event "metaData.extra.shape" equals "line"
        And the event breadcrumbs contain "Crumb left before crash"

    Scenario: The app is terminated normally
        The application can be gracefully terminated by the OS if more
        memory is needed for other applications or directly by calling
        exit(0)

        When I crash the app using "OOMWillTerminateScenario"
        And I wait for 4 seconds
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: The app is terminated normally
        The application can be gracefully terminated by the OS if more
        memory is needed for other applications or directly by calling
        exit(0)

        When I crash the app using "OOMWillTerminateScenario"
        And I wait for 4 seconds
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: The OS kills the application in the background
        When I run "OOMScenario"
        And I put the app in the background
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: The OS kills the application in the background and reportBackgroundOOMs is true
        When I run "ReportBackgroundOOMsEnabledScenario"
        And I put the app in the background
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests

    Scenario: The OS kills the application after a session is sent
        When I set environment variable "BUGSNAG_API_KEY" to "0192837465afbecd0192837465afbecd"
        And I crash the app using "SessionOOMScenario"
        And I wait for 2 requests
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 3 requests
        And request 0 is a valid for the session tracking API
        And request 1 is a valid for the error reporting API
        And request 2 is a valid for the error reporting API
        And the payload field "events" is an array with 1 element for request 2
        And the payload field "events.0.session.events.handled" equals 1 for request 1
        And the payload field "events.0.session.events.unhandled" equals 0 for request 1
        And the payload field "events.0.session.events.handled" equals 1 for request 2
        And the payload field "events.0.session.events.unhandled" equals 1 for request 2
        And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0
        And the payload field "events.0.session.id" of request 1 equals the payload field "events.0.session.id" of request 2

    Scenario: The OS kills the application after a session is stopped
        When I set environment variable "BUGSNAG_API_KEY" to "0192837465afbecd0192837465afbecd"
        And I crash the app using "StopSessionOOMScenario"
        And I wait for 2 requests
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 3 requests
        And request 0 is a valid for the session tracking API
        And request 1 is a valid for the error reporting API
        And request 2 is a valid for the error reporting API
        And the payload field "events" is an array with 1 element for request 2
        And the payload field "events.0.session.events.handled" equals 1 for request 1
        And the payload field "events.0.session.events.unhandled" equals 0 for request 1
        And the payload field "events.0.session" is null for request 2
        And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0

    Scenario: The OS kills the application after a session is resumed
        When I set environment variable "BUGSNAG_API_KEY" to "0192837465afbecd0192837465afbecd"
        When I crash the app using "ResumeSessionOOMScenario"
        And I wait for 2 requests
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 3 requests
        And request 0 is a valid for the session tracking API
        And request 1 is a valid for the error reporting API
        And request 2 is a valid for the error reporting API
        And the payload field "events" is an array with 1 element for request 2
        And the payload field "events.0.session.events.handled" equals 1 for request 1
        And the payload field "events.0.session.events.unhandled" equals 0 for request 1
        And the payload field "events.0.session.events.handled" equals 1 for request 2
        And the payload field "events.0.session.events.unhandled" equals 1 for request 2
        And the payload field "events.0.session.id" of request 1 equals the payload field "sessions.0.id" of request 0
        And the payload field "events.0.session.id" of request 1 equals the payload field "events.0.session.id" of request 2

    Scenario: The OS kills the application in the foreground when reportOOMs is false
        When I run "ReportOOMsDisabledScenario"
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 4 seconds
        Then I should receive 0 requests

    Scenario: The OS kills the application in the background when reportOOMs is false
        When I run "ReportOOMsDisabledScenario"
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 4 seconds
        Then I should receive 0 requests

    Scenario: The OS kills the application in the background when reportOOMs is false and reportBackgroundOOMs is true
        When I run "ReportOOMsDisabledReportBackgroundOOMsEnabledScenario"
        And I put the app in the background
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 4 seconds
        Then I should receive 0 requests
