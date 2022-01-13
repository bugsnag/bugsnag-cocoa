Feature: Launch detection

  Background:
    Given I clear all persistent data

  Scenario: LastRunInfo consecutiveLaunchCrashes increments when isLaunching is true
    When I run "LastRunInfoScenario" and relaunch the crashed app
    And I configure Bugsnag for "LastRunInfoScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 1
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is true
    And I discard the oldest error

    And I run the configured scenario and relaunch the crashed app
    And I configure Bugsnag for "LastRunInfoScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 2
    And I discard the oldest error

    And I run the configured scenario and relaunch the crashed app
    And I configure Bugsnag for "LastRunInfoScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 3
    And I discard the oldest error

    And I run the configured scenario and relaunch the crashed app
    And I configure Bugsnag for "LastRunInfoScenario"
    And I wait to receive an error
    And the event "metaData.lastRunInfo.consecutiveLaunchCrashes" equals 0
    And the event "metaData.lastRunInfo.crashed" is true
    And the event "metaData.lastRunInfo.crashedDuringLaunch" is false
