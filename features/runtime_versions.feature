Feature: Runtime versions are included in all requests

Scenario: Runtime versions included in Cocoa error
    When I run "HandledErrorScenario"
    Then I should receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
    And the payload field "events.0.device.runtimeVersions.clangVersion" is not null

Scenario: Runtime versions included in Cocoa session
    When I run "ManualSessionScenario"
    And I wait for 10 seconds
    Then I should receive a request
    And the request is a valid for the session tracking API
    And the payload field "device.runtimeVersions.osBuild" is not null
    And the payload field "device.runtimeVersions.clangVersion" is not null
