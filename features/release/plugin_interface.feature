Feature: Add custom behavior through a plugin interface

  Some internal libraries may build on top of the Bugsnag Cocoa library and
  require custom behavior prior to the library being fully initialized. This
  interface allows for installing that behavior before calling the regular
  initialization process.

  Background:
    Given I clear all persistent data

  Scenario: Changing payload notifier description
    When I run "CustomPluginNotifierDescriptionScenario" and relaunch the crashed app
    And I configure Bugsnag for "CustomPluginNotifierDescriptionScenario"
    And I wait to receive an error
    Then the error payload field "notifier.name" equals "Foo Handler Library"
    And the error payload field "notifier.version" equals "2.1.0"
    And the error payload field "notifier.url" equals "https://example.com"
    And the exception "errorClass" equals one of:
      | ARM   | EXC_BREAKPOINT      |
      | Intel | EXC_BAD_INSTRUCTION |
