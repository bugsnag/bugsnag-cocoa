Feature: Metadata values can be redacted
  Values added to metadata can be redacted through the use of config.redactedKeys

  Background:
    Given I clear all persistent data

  Scenario: Default behaviour redacts 'password' values after callback is run
    When I run "MetadataRedactionDefaultScenario"
    And I wait to receive a request
    Then the request is valid for the error reporting API
    And the event "metaData.custom.password" equals "[REDACTED]"
    And the event "metaData.custom.Password" equals "[REDACTED]"
    And the event "metaData.custom.password2" equals "not redacted"
    And the event "metaData.custom.normalKey" equals "brown fox"
    And the event "metaData.extras.callbackValue" equals "hunter2"

  Scenario: Redaction works in deeply nested objects with custom keys
    When I run "MetadataRedactionNestedScenario"
    And I wait to receive a request
    And the event "metaData.custom.alpha.password" equals "foo"
    And the event "metaData.custom.alpha.name" equals "[REDACTED]"
    And the event "metaData.custom.beta.gamma.password" equals "foo"
    And the event "metaData.custom.beta.gamma.age" equals "[REDACTED]"
    And the event "metaData.custom.beta.gamma.name" equals "[REDACTED]"

  Scenario: Regex values are redacted
    When I run "MetadataRedactionRegexScenario"
    And I wait to receive a request
    And the event "metaData.animals.cat" equals "[REDACTED]"
    And the event "metaData.clothes.hat" equals "[REDACTED]"
    And the event "metaData.debris.9at" equals "unknown"
