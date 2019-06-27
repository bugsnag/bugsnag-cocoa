Feature: Runtime versions are included in all requests

Scenario: Runtime versions included in Cocoa error
    When I run "HandledErrorScenario"
    And I wait for a request
    Then the request is valid for the error reporting API
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
    And the payload field "events.0.device.runtimeVersions.clangVersion" is not null

Scenario: Runtime versions included in Cocoa session
    When I run "ManualSessionScenario"
    And I wait for a request
    Then the request is valid for the session tracking API
    And the payload field "device.runtimeVersions.osBuild" is not null
    And the payload field "device.runtimeVersions.clangVersion" is not null

Scenario: Runtime versions included in C layer ThrownErrorScenario
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "CxxExceptionScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
