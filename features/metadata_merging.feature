Feature: Metadata values are merged in a defined order

  Background:
    Given I clear all persistent data

  Scenario: Merging metadata values
    When I run "MetadataMergeScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "metaData.custom.nonNullValue" equals "overriddenValue"
    And the event "metaData.custom.nullValue" is null
    And the event "metaData.custom.invalidValue" equals "initialValue"
