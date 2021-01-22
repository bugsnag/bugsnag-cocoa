Feature: Attaching a series of notable events leading up to errors
  A breadcrumb contains supplementary data which will be sent along with
  events. Breadcrumbs are intended to be pieces of information which can
  lead the developer to the cause of the event being reported.

  Background:
    Given I clear all persistent data

  Scenario: Manually leaving a breadcrumb of a discarded type and discarding automatic
    When I run "DiscardedBreadcrumbTypeScenario"
    And I wait to receive an error
    Then the event has a "log" breadcrumb named "Noisy event"
    And the event has a "process" breadcrumb named "Important event"
    And the event does not have a "event" breadcrumb

  Scenario: Leaving breadcrumbs when enabledBreadcrumbTypes is empty
    When I run "EnabledBreadcrumbTypesIsNilScenario"
    And I wait to receive an error
    Then the event has a "log" breadcrumb named "Noisy event"
    And the event has a "process" breadcrumb named "Important event"

  Scenario: An app lauches and subsequently sends a manual event using notify()
    When I run "HandledErrorScenario"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"

  Scenario: An app lauches and subsequently crashes
    When I run "BuiltinTrapScenario" and relaunch the app
    And I configure Bugsnag for "BuiltinTrapScenario"
    And I wait to receive an error
    Then the event has a "state" breadcrumb named "Bugsnag loaded"

  Scenario: Modifying a breadcrumb name
    When I run "ModifyBreadcrumbScenario"
    And I wait to receive an error
    Then the event has a "manual" breadcrumb named "Cache locked"

  Scenario: Modifying a breadcrumb name in callback
    When I run "ModifyBreadcrumbInNotify"
    And I wait to receive an error
    Then the event has a "manual" breadcrumb named "Cache locked"
