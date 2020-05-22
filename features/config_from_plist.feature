Feature: Loading Bugsnag configuration from Info.plist
    Configuration options can be specified in build at build time to avoid
    writing code for those options.

    Scenario: Specifying config in Info.plist
        When I run "LoadConfigFromFileScenario"
        And I wait to receive a request
        And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
        And the event "metaData.nserror.domain" equals "iOSTestApp.LaunchError"
        And the event "app.releaseStage" equals "beta2"

