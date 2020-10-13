Feature: Out of memory errors

  Background:
    Given I clear all persistent data

  Scenario: Out of memory errors are enabled when loading configuration
    When I run "OOMLoadScenario"
    And I wait to receive a request
    And the "Bugsnag-API-Key" header equals "0192837465afbecd0192837465afbecd"
    And the error is an OOM event

    # Ensure the basic data from OOMs are present
    And the event "device.jailbroken" is false
    And the event "metaData.device.timezone" is not null
    And the event "metaData.device.simulator" is false
    And the event "metaData.device.wordSize" is not null
    And the event "app.id" equals "com.bugsnag.iOSTestApp"
    And the event "metaData.app.name" equals "iOSTestApp"
    And the event "app.inForeground" is true
    And the event "app.type" equals "iOS"
    And the event "app.bundleVersion" is not null
    And the event "app.version" is not null

  Scenario: Out of memory errors are disabled by AutoDetectErrors
    When I run "OOMAutoDetectErrorsScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "unhandled" is false
    And the exception "message" equals "OOMAutoDetectErrorsScenario"

  Scenario: Out of memory errors are disabled by EnabledErrorTypes
    When I run "OOMEnabledErrorTypesScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And the event "unhandled" is false
    And the exception "message" equals "OOMEnabledErrorTypesScenario"

  