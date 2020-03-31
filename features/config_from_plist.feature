Feature: Loading Bugsnag configuration from Info.plist
    Configuration options can be specified in build at build time to avoid
    writing code for those options.

    Scenario: Specifying config in Info.plist
        When I run "LoadConfigFromFileScenario"
        And I wait to receive a request
        Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
        And the event "metaData.nserror.domain" equals "iOSTestApp.LaunchError"
        And the event "app.releaseStage" equals "beta2"

