Feature: Reporting out of memory events
    If the app is terminated without either a reported crash or a "will
    terminate" event, and the underlying OS and app versions remain the same,
    it is likely that the app has been killed.

    Background:
        When I run "ClearOOMsScenario"
        And I wait for 3 seconds
        And I relaunch the app
        And I clear the request queue

    Scenario: The OS kills the application in the foreground
        When I run "OOMDeviceScenario" and relaunch the app
        And I configure Bugsnag for "OOMDeviceScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the exception "errorClass" equals "Out Of Memory"
        And the exception "message" equals "The app was likely terminated by the operating system while in the foreground"
        And the event "unhandled" is true
        And the event "severity" equals "error"
        And the event "severityReason.type" equals "outOfMemory"
        And the event "app.releaseStage" equals "beta"
        And the event "app.version" equals "1.0.3"
        And the event "app.bundleVersion" equals "5"
        And the event breadcrumbs contain "Crumb left before crash"

    @wip
    Scenario: The OS kills the application in the background
        When I run "OOMDeviceScenario"
        And I send the app to the background for 10 seconds
        And I relaunch the app
        And I configure Bugsnag for "OOMDeviceScenario"
        And I wait for 10 seconds
        Then I should receive no requests

    @wip
    Scenario: The OS kills the application in the background and reportBackgroundOOMs is true
        When I run "ReportBackgroundOOMsEnabledDeviceScenario"
        And I send the app to the background for 30 seconds
        And I relaunch the app
        And I configure Bugsnag for "ReportBackgroundOOMsEnabledDeviceScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the exception "errorClass" equals "Out Of Memory"
        And the exception "message" equals "The app was likely terminated by the operating system while in the background"
        And the event "unhandled" is true
        And the event "severity" equals "error"
        And the event "severityReason.type" equals "outOfMemory"
        And the event "app.releaseStage" equals "beta"
        And the event "app.version" equals "1.0.3"
        And the event "app.bundleVersion" equals "5"
        And the event breadcrumbs contain "Crumb left before crash"

    Scenario: The OS kills the application after a session is sent
        When I run "SessionOOMDeviceScenario" and relaunch the app
        And I configure Bugsnag for "SessionOOMDeviceScenario"
        And I wait to receive 3 requests
        And the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "sessions.0.id" is stored as the value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session.events.handled" equals 1
        And the payload field "events.0.session.events.unhandled" equals 0
        And the payload field "events.0.session.id" equals the stored value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session.events.handled" equals 1
        And the payload field "events.0.session.events.unhandled" equals 1
        And the payload field "events.0.session.id" equals the stored value "session_id"

    Scenario: The OS kills the application after a session is stopped
        When I run "StopSessionOOMDeviceScenario" and relaunch the app
        And I configure Bugsnag for "StopSessionOOMDeviceScenario"
        And I wait to receive 3 requests
        And the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "sessions.0.id" is stored as the value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session.events.handled" equals 1
        And the payload field "events.0.session.events.unhandled" equals 0
        And the payload field "events.0.session.id" equals the stored value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session" is null

    Scenario: The OS kills the application after a session is resumed
        When I run "ResumeSessionOOMDeviceScenario" and relaunch the app
        And I configure Bugsnag for "ResumeSessionOOMDeviceScenario"
        And I wait to receive 3 requests
        And the request is valid for the session reporting API version "1.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "sessions.0.id" is stored as the value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session.events.handled" equals 1
        And the payload field "events.0.session.events.unhandled" equals 0
        And the payload field "events.0.session.id" equals the stored value "session_id"
        And I discard the oldest request
        And the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the payload field "events" is an array with 1 elements
        And the payload field "events.0.session.events.handled" equals 1
        And the payload field "events.0.session.events.unhandled" equals 1
        And the payload field "events.0.session.id" equals the stored value "session_id"

    Scenario: The OS kills the application in the foreground when reportOOMs is false
        When I run "ReportOOMsDisabledDeviceScenario"
        And I wait for 10 seconds
        And I relaunch the app
        And I configure Bugsnag for "ReportOOMsDisabledDeviceScenario"
        And I wait for 5 seconds
        Then I should receive no requests

    @wip
    Scenario: The OS kills the application in the background when reportOOMs is false
        When I run "ReportOOMsDisabledDeviceScenario"
        And I send the app to the background for 10 seconds
        And I relaunch the app
        And I configure Bugsnag for "ReportOOMsDisabledDeviceScenario"
        And I wait for 10 seconds
        Then I should receive no requests

    @wip
    Scenario: The OS kills the application in the background when reportOOMs is false and reportBackgroundOOMs is true
        When I run "ReportOOMsDisabledReportBackgroundOOMsEnabledDeviceScenario"
        And I send the app to the background for 10 seconds
        And I relaunch the app
        And I configure Bugsnag for "ReportOOMsDisabledReportBackgroundOOMsEnabledDeviceScenario"
        And I wait for 10 seconds
        Then I should receive no requests
