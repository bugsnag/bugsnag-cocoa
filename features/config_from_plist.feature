Feature: Loading Bugsnag configuration from Info.plist
  Configuration options can be specified in build at build time to avoid
  writing code for those options.

    Background:
        Given I clear all persistent data

    Scenario: Specifying config in Info.plist
        When I run "LoadConfigFromFileScenario"
        And I wait to receive 2 requests
        And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
        And the payload field "sessions" is not null
        And I discard the oldest request
        And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
        And the event "metaData.nserror.domain" equals the platform-dependent string:
          | ios   | iOSTestApp.LaunchError   |
          | macos | macOSTestApp.LaunchError |
        And the event "app.releaseStage" equals "beta2"

    Scenario: Calling Bugsnag.start() with no configuration
        When I run "LoadConfigFromFileAutoScenario"
        And I wait to receive 2 requests
        And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
        And the payload field "sessions" is not null
        And I discard the oldest request
        And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
        And the event "metaData.nserror.domain" equals the platform-dependent string:
          | ios   | iOSTestApp.LoadConfigFromFileAutoScenarioError   |
          | macos | macOSTestApp.LoadConfigFromFileAutoScenarioError |
        And the event "app.releaseStage" equals "beta2"
