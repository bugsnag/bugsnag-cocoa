Feature: Loading Bugsnag configuration from Info.plist
    Configuration options can be specified in build at build time to avoid
    writing code for those options.

    Scenario: Specifying config in Info.plist
        When I run "LoadConfigFromFileScenario"
        And I wait for a request
        Then the request is valid for the error reporting API
        And the "Bugsnag-API-Key" header equals "233276324dfac2"
        And the event "metaData.nserror.domain" equals "iOSTestApp.LaunchError"
        And the event "app.releaseStage" equals "beta2"

