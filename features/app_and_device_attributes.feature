Feature: App and Device attributes present

  Background:
    Given I clear all persistent data

  Scenario: App and Device info is as expected
    When I run "AppAndDeviceAttributesScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    # Device

    And the payload field "events.0.device.osName" equals the platform-dependent string:
      | ios   | iOS    |
      | macos | Mac OS |
    And the payload field "events.0.device.jailbroken" is false
    And the payload field "events.0.device.osVersion" matches the regex "\d+\.\d+"
    And the payload field "events.0.device.manufacturer" equals "Apple"
    And the payload field "events.0.device.locale" is not null
    And the payload field "events.0.device.id" is not null
    And the payload field "events.0.device.model" matches the test device model
    # modelNumber is not available on macOS
    # And the payload field "events.0.device.modelNumber" is not null
    And the payload field "events.0.device.runtimeVersions.osBuild" is not null
    And the payload field "events.0.device.runtimeVersions.clangVersion" is not null
    And the payload field "events.0.device.totalMemory" is an integer

    # DeviceWithState

    And the payload field "events.0.device.freeDisk" is an integer
    And the payload field "events.0.device.freeMemory" is an integer
    #And the payload field "events.0.device.orientation" equals "portrait"
    And the payload field "events.0.device.time" is a date

    # App

    # (codeBundleId is RN only, so omitted)
    And the payload field "events.0.app.bundleVersion" is not null
    #And the payload field "events.0.app.dsymUUIDs" is a non-empty array # Fails, == nil
    And the payload field "events.0.app.id" equals the platform-dependent string:
      | ios   | com.bugsnag.iOSTestApp   |
      | macos | com.bugsnag.macOSTestApp |
    And the payload field "events.0.app.releaseStage" equals "development"
    And the payload field "events.0.app.type" equals the platform-dependent string:
      | ios   | iOS   |
      | macos | macOS |
    And the payload field "events.0.app.version" equals "1.0.3"

    # AppWithState

    And the payload field "events.0.app.duration" is a number
    And the payload field "events.0.app.durationInForeground" is a number
    And the payload field "events.0.app.inForeground" is not null

  Scenario: App and Device info is as expected when overridden via config
    When I run "AppAndDeviceAttributesScenarioConfigOverride"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    And the payload field "events.0.app.type" equals "iLeet"
    And the payload field "events.0.app.bundleVersion" equals "12345"
    And the payload field "events.0.context" equals "myContext"
    And the payload field "events.0.app.releaseStage" equals "secondStage"

  Scenario: App and Device info is as expected when overridden via callback
    When I run "AppAndDeviceAttributesScenarioCallbackOverride"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    And the payload field "events.0.app.type" equals "newAppType"
    And the payload field "events.0.app.bundleVersion" equals "42"
    And the payload field "events.0.app.version" equals "999"
    And the payload field "events.0.app.releaseStage" equals "thirdStage"
    And the payload field "events.0.device.manufacturer" equals "Nokia"
    And the payload field "events.0.device.modelNumber" equals "0898"
