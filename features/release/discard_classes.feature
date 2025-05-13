Feature: Configuration discardClasses option

  Background:
    Given I clear all persistent data

  Scenario: Discard handled exception via regular expression
    When I run "DiscardClassesHandledExceptionRegexScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"

# TODO Restore before PLAT-13748 is closed
@skip
  Scenario: Discard unhandled exception
    When I run "DiscardClassesUnhandledExceptionScenario" and relaunch the crashed app
    And I configure Bugsnag for "DiscardClassesUnhandledExceptionScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"

# TODO Restore before PLAT-13748 is closed
@skip
  Scenario: Discard unhandled crash
    When I run "DiscardClassesUnhandledCrashScenario" and relaunch the crashed app
    And I configure Bugsnag for "DiscardClassesUnhandledCrashScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"
