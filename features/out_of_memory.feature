Feature: Reporting out of memory events
    If the app is terminated without either a reported crash or a "will
    terminate" event, and the underlying OS and app versions remain the same,
    it is likely that the app has been killed.

    Scenario: The app is terminated normally
        The application can be gracefully terminated by the OS if more
        memory is needed for other applications or directly by calling
        exit(0). This should not trigger an OOM notification.

        When I run "OOMWillTerminateScenario"
        And The app is not running
        And I relaunch the app
        And I wait for 5 seconds
        Then I should receive no requests

    Scenario: An OOM occurs in the foreground
        When I run "OOMForegroundScenario"
        And The app is not running
        And I relaunch the app
        And I configure Bugsnag for "OOMForegroundScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the exception "errorClass" equals "Out Of Memory"
        And the exception "message" equals "The app was likely terminated by the operating system while in the foreground"
        And the event "unhandled" is true
        And the event "severity" equals "error"
        And the event "severityReason.type" equals "outOfMemory"
        And the event "app.releaseStage" equals "alpha"
        And the event "app.version" equals "1.0.3"
        And the event "app.bundleVersion" equals "5"
        And the event "metaData.extra.shape" equals "line"
        And the event breadcrumbs contain "Crumb left before crash"

    Scenario: An OOM occurs in the foreground when reportOOMs is false
      When I set the app to "reportOOMsFalse" mode
      And I run "OOMForegroundScenario"
      And The app is not running
      And I wait for 5 second
      And I relaunch the app
      And I set the app to "reportOOMsFalse" mode
      And I configure Bugsnag for "OOMForegroundScenario"
      And I wait for 5 seconds
      Then I should receive no requests

    Scenario: An OOM occurs in the background
      When I configure Bugsnag for "OOMBackgroundScenario"
      And I send the app to the background
      And The app is not running
      And I relaunch the app
      And I configure Bugsnag for "OOMBackgroundScenario"
      And I wait for 5 seconds
      Then I should receive no requests

    Scenario: An OOM occurs after a session is sent

    Scenario: An OOM occurs after a session is stopped

    Scenario: An OOM occurs after a session is resumed
