Feature: Callbacks can access and modify breadcrumb information

  Background:
    Given I clear all persistent data

  Scenario: Returning false in a callback discards breadcrumbs
    When I run "BreadcrumbCallbackDiscardScenario"
    And I wait to receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.breadcrumbs" is an array with 1 elements
    And the payload field "events.0.breadcrumbs.0.name" equals "Hello World"
    And the payload field "events.0.breadcrumbs.0.type" equals "manual"
    And the payload field "events.0.breadcrumbs.0.timestamp" is a parsable timestamp in seconds
    And the payload field "events.0.breadcrumbs.0.metaData.foo" equals "bar"
    And the payload field "events.0.breadcrumbs.0.metaData.addedVal" is true

  Scenario: Callbacks execute in the order in which they were added
    When I run "BreadcrumbCallbackOrderScenario"
    And I wait to receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.breadcrumbs" is an array with 1 elements
    And the payload field "events.0.breadcrumbs.0.name" equals "Hello World"
    And the payload field "events.0.breadcrumbs.0.type" equals "manual"
    And the payload field "events.0.breadcrumbs.0.timestamp" is a parsable timestamp in seconds
    And the payload field "events.0.breadcrumbs.0.metaData.firstCallback" equals 0
    And the payload field "events.0.breadcrumbs.0.metaData.secondCallback" equals 1

  Scenario: Modifying breadcrumb information with a callback
    When I run "BreadcrumbCallbackOverrideScenario"
    And I wait to receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.breadcrumbs" is an array with 1 elements
    And the payload field "events.0.breadcrumbs.0.name" equals "Feliz Navidad"
    And the payload field "events.0.breadcrumbs.0.type" equals "manual"
    And the payload field "events.0.breadcrumbs.0.timestamp" is a parsable timestamp in seconds
    And the payload field "events.0.breadcrumbs.0.metaData.foo" equals "wham"

  Scenario: Callbacks can be removed without affecting the functionality of other callbacks
    When I run "BreadcrumbCallbackRemovalScenario"
    And I wait to receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.breadcrumbs" is an array with 1 elements
    And the payload field "events.0.breadcrumbs.0.name" equals "Hello World"
    And the payload field "events.0.breadcrumbs.0.type" equals "manual"
    And the payload field "events.0.breadcrumbs.0.timestamp" is a parsable timestamp in seconds
    And the payload field "events.0.breadcrumbs.0.metaData.foo" equals "bar"
    And the payload field "events.0.breadcrumbs.0.metaData.firstCallback" equals "Whoops"

  Scenario: An uncaught NSException in a callback does not affect breadcrumb delivery
    When I run "BreadcrumbCallbackCrashScenario"
    And I wait to receive a request
    And the request is valid for the error reporting API
    And the payload field "events.0.breadcrumbs" is an array with 1 elements
    And the payload field "events.0.breadcrumbs.0.name" equals "Hello World"
    And the payload field "events.0.breadcrumbs.0.type" equals "manual"
    And the payload field "events.0.breadcrumbs.0.timestamp" is a parsable timestamp in seconds
    And the payload field "events.0.breadcrumbs.0.metaData.foo" equals "bar"
    And the payload field "events.0.breadcrumbs.0.metaData.addedInCallback" is true
    And the payload field "events.0.breadcrumbs.0.metaData.shouldNotHappen" is null
    And the payload field "events.0.breadcrumbs.0.metaData.secondCallback" is true
