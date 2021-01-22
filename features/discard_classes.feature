Feature: Configuration discardClasses option

  Background:
    Given I clear all persistent data

  Scenario: Discard handled exception via regular expression
    When I run "DiscardClassesHandledExceptionRegexScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"

  Scenario: Discard unhandled exception
    When I run "DiscardClassesUnhandledExceptionScenario" and relaunch the app
    And I configure Bugsnag for "DiscardClassesUnhandledExceptionScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"

  Scenario: Discard unhandled crash
    When I run "DiscardClassesUnhandledCrashScenario" and relaunch the app
    And I configure Bugsnag for "DiscardClassesUnhandledCrashScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "NotDiscarded"
