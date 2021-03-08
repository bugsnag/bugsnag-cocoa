Feature: App hangs

  Background:
    Given I clear all persistent data

  Scenario: App hangs above the threshold should be reported
    When I set the app to "2.1" mode
    And I run "AppHangScenario"
    And I wait to receive an error

    #
    # App hang specific values
    #

    And the event "severity" equals "error"
    And the event "severityReason.type" equals "appHang"
    And the event "threads.0.errorReportingThread" is true

    And the exception "errorClass" equals "App Hang"
    And the exception "message" equals "The app's main thread failed to respond to an event within 2000 milliseconds"
    And the exception "type" equals "cocoa"

    #
    # Checks copied from app_and_device_attributes.feature
    #

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

  Scenario: App hangs below the threshold should not be reported
    When I set the app to "1.8" mode
    And I run "AppHangScenario"
    And I should receive no errors

  Scenario: App hangs should not be reported if enabledErrorTypes.appHangs = false
    When I run "AppHangDisabledScenario"
    Then I should receive no errors
