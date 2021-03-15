Feature: Launch detection

  Background:
    Given I clear all persistent data

  Scenario: LastRunInfo consecutiveLaunchCrashes increments when isLaunching is true
    When I run "LastRunInfoConsecutiveLaunchCrashesScenario" and relaunch the app
    And I configure Bugsnag for "LastRunInfoConsecutiveLaunchCrashesScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 1
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is true
    And I discard the oldest error

    And I click the element "run_scenario"
    And I wait for 1 seconds
    And I relaunch the app
    And I configure Bugsnag for "LastRunInfoConsecutiveLaunchCrashesScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 2
    And I discard the oldest error

    And I click the element "run_scenario"
    And I relaunch the app
    And I configure Bugsnag for "LastRunInfoConsecutiveLaunchCrashesScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 3
    And I discard the oldest error

    And I wait for 5 seconds

    And I click the element "run_scenario"
    And I relaunch the app
    And I configure Bugsnag for "LastRunInfoConsecutiveLaunchCrashesScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 0
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is false
