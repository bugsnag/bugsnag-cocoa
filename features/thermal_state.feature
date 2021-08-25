# Thermal state is not available prior to iOS/tvOS 11 and macOS 10.10.3
@skip_below_ios_11
Feature: Thermal State

  Background:
    Given I clear all persistent data

  Scenario: Thermal state metadata is always present
    When I run "HandledErrorScenario"
    And I wait to receive an error
    Then the event "metaData.device.thermalState" matches "(nominal|fair|serious|critical)"

  Scenario: Thermal state breadcrumb
    When I run "ThermalStateBreadcrumbScenario"
    And I wait to receive an error
    Then the event "metaData.device.thermalState" matches "critical"
    And the event "breadcrumbs.1.name" equals "Thermal State Changed"
    And the event "breadcrumbs.1.metaData.from" matches "(nominal|fair|serious)"
    And the event "breadcrumbs.1.metaData.to" equals "critical"
    And the event "breadcrumbs.1.type" equals "state"

  Scenario: Thermal Kill
    When I run "CriticalThermalStateScenario"
    And I wait for 2 seconds
    And I relaunch the app
    And I configure Bugsnag for "CriticalThermalStateScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "Thermal Kill"
    And the exception "message" equals "The app was terminated by the operating system due to a critical thermal state"
    And the event "metaData.device.thermalState" matches "critical"
    And the event "breadcrumbs.1.name" equals "Thermal State Changed"
    And the event "breadcrumbs.1.metaData.from" matches "(nominal|fair|serious)"
    And the event "breadcrumbs.1.metaData.to" equals "critical"
    And the event "breadcrumbs.1.type" equals "state"
    And the event "session.events.handled" equals 0
    And the event "session.events.unhandled" equals 1
    And the event "severity" equals "error"
    And the event "severityReason.type" equals "thermalKill"
    And the event "severityReason.unhandledOverridden" is null
    And the event "unhandled" is true

  # The "I send the app to the background" step is not available on macOS
  @skip_macos
  Scenario: Thermal Kills should not be reported if app was in the background
    When I run "CriticalThermalStateScenario"
    And I wait to receive a session
    And I discard the oldest session
    And I send the app to the background
    And I relaunch the app
    And I configure Bugsnag for "CriticalThermalStateScenario"
    And I wait to receive a session
    Then I should receive no errors
