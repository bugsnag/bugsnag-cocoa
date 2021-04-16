Feature: App and Device attributes present

  Background:
    Given I clear all persistent data

  Scenario: App and Device info is as expected
    When I run "AppAndDeviceAttributesScenario"
    And I wait to receive 2 errors
    Then the error is valid for the error reporting API
    And the error "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    # Device

    And the error payload field "events.0.device.osName" equals the platform-dependent string:
      | ios   | iOS    |
      | macos | Mac OS |
    And the error payload field "events.0.device.jailbroken" is false
    And the error payload field "events.0.device.osVersion" matches the regex "\d+\.\d+"
    And the error payload field "events.0.device.manufacturer" equals "Apple"
    And the error payload field "events.0.device.locale" is not null
    And the error payload field "events.0.device.id" is not null
    And the error payload field "events.0.device.model" matches the test device model
    And the error payload field "events.0.device.modelNumber" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the error payload field "events.0.device.runtimeVersions.osBuild" is not null
    And the error payload field "events.0.device.runtimeVersions.clangVersion" is not null
    And the error payload field "events.0.device.totalMemory" is an integer

    # DeviceWithState

    And the error payload field "events.0.device.freeDisk" is an integer
    And the error payload field "events.0.device.freeMemory" is an integer
    And the error payload field "events.0.device.orientation" equals the platform-dependent string:
      | ios   | @not_null |
      | macos | @null     |
    And the error payload field "events.0.device.time" is a date
    And the event "device.freeMemory" is less than the event "device.totalMemory"

    # App

    # (codeBundleId is RN only, so omitted)
    And the error payload field "events.0.app.bundleVersion" is not null
    #And the error payload field "events.0.app.dsymUUIDs" is a non-empty array # Fails, == nil
    And the error payload field "events.0.app.id" equals the platform-dependent string:
      | ios   | com.bugsnag.iOSTestApp   |
      | macos | com.bugsnag.macOSTestApp |
    And the error payload field "events.0.app.isLaunching" is true
    And the error payload field "events.0.app.releaseStage" equals "development"
    And the error payload field "events.0.app.type" equals the platform-dependent string:
      | ios   | iOS   |
      | macos | macOS |
    And the error payload field "events.0.app.version" equals "1.0.3"

    # AppWithState

    And the error payload field "events.0.app.duration" is a number
    And the error payload field "events.0.app.durationInForeground" is a number
    And the error payload field "events.0.app.inForeground" is not null

    # App metadata

    And the event "metaData.app.binaryArch" is not null
    And the event "metaData.app.name" equals the platform-dependent string:
      | ios   | iOSTestApp   |
      | macos | macOSTestApp |

    And I discard the oldest error
    And the event "app.isLaunching" is false

  Scenario: App and Device info is as expected when overridden via config
    When I run "AppAndDeviceAttributesScenarioConfigOverride"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    And the error payload field "events.0.app.type" equals "iLeet"
    And the error payload field "events.0.app.bundleVersion" equals "12345"
    And the error payload field "events.0.context" equals "myContext"
    And the error payload field "events.0.app.releaseStage" equals "secondStage"

  Scenario: App and Device info is as expected when overridden via callback
    When I run "AppAndDeviceAttributesScenarioCallbackOverride"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the error "Bugsnag-API-Key" header equals "12312312312312312312312312312312"

    And the error payload field "events.0.app.type" equals "newAppType"
    And the error payload field "events.0.app.bundleVersion" equals "42"
    And the error payload field "events.0.app.version" equals "999"
    And the error payload field "events.0.app.releaseStage" equals "thirdStage"
    And the error payload field "events.0.device.manufacturer" equals "Nokia"
    And the error payload field "events.0.device.modelNumber" equals "0898"

  Scenario: Duration value increments as expected
    When I run "AppDurationScenario"
    And I wait to receive 3 errors
    And the event "app.duration" is between 0 and 200
    And I discard the oldest error
    And the event "app.duration" is between 2600 and 2800
    And I discard the oldest error
    And the event "app.duration" is between 5400 and 5600

  Scenario: isLaunching should be true if launchDurationMillis is 0
    When I run "AppAndDeviceAttributesInfiniteLaunchDurationScenario"
    And I wait to receive an error
    And the event "app.isLaunching" is true

  Scenario: isLaunching is true for unhandled exception during launch
    When I run "AppAndDeviceAttributesUnhandledExceptionDuringLaunchScenario" and relaunch the app
    And I configure Bugsnag for "AppAndDeviceAttributesUnhandledExceptionDuringLaunchScenario"
    And I wait to receive an error
    And the event "app.isLaunching" is true

  Scenario: isLaunching is false for unhandled exception after launch
    When I run "AppAndDeviceAttributesUnhandledExceptionAfterLaunchScenario" and relaunch the app
    And I configure Bugsnag for "AppAndDeviceAttributesUnhandledExceptionAfterLaunchScenario"
    And I wait to receive an error
    And the event "app.isLaunching" is false
