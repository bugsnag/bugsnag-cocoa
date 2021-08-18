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
