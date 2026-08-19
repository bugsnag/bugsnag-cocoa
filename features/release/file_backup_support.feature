Feature: File backup support metadata

  Background:
    Given I clear all persistent data

  # ─── SCENARIO 1: Fresh install applies expected backup metadata (4 cases) ──────────
  @skip_watchos
  Scenario Outline: Fresh install applies expected backup metadata to SDK-managed paths
    Given I set the app to "<mode>" mode
    And I set the HTTP status code to 500
    When I configure Bugsnag for "InternalWorkingsScenario"
    And I invoke "prepareBackupStorage"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    And I invoke "reportBackupMetadataSnapshot"
    And I wait to receive an error
    Then the backup metadata snapshot is consistent for setting "<setting>"

    Examples:
      | mode                   | setting |
      | backup_default         | false   |
      | backup_false           | false   |
      | backup_true            | true    |
      | backup_false_unrelated | false   |

  # ─── SCENARIO 2: Existing SDK storage normalized across config changes and relaunches (6 cases) ──
  @skip_watchos
  Scenario Outline: Existing SDK storage is normalized across config changes and relaunches
    Given I set the app to "<previous_mode>" mode
    And I set the HTTP status code to 500
    And I configure Bugsnag for "InternalWorkingsScenario"
    And I invoke "prepareBackupStorage"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    And I kill and relaunch the app
    And I set the app to "<current_mode>" mode
    When I configure Bugsnag for "InternalWorkingsScenario"
    And I wait to receive an error
    And I discard the oldest error
    And I invoke "reportBackupMetadataSnapshot"
    And I wait to receive an error
    Then the backup metadata snapshot is consistent for setting "<setting>"

    Examples:
      | previous_mode | current_mode       | setting |
      | backup_false  | backup_true        | true    |
      | backup_true   | backup_false       | false   |
      | backup_false  | backup_false_mixed | false   |
      | backup_true   | backup_true_mixed  | true    |
      | backup_false  | backup_false       | false   |
      | backup_true   | backup_true        | true    |

  # ─── SCENARIO 3: SDK rewrites and replacements preserve active backup metadata (2 cases) ──
  @skip_watchos
  Scenario Outline: SDK rewrites and replacements preserve active backup metadata
    Given I set the app to "backup_<setting>" mode
    And I set the HTTP status code to 500
    When I configure Bugsnag for "InternalWorkingsScenario"
    And I invoke "prepareBackupStorage"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    When I invoke "exerciseBackupRewrites"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    And I invoke "reportBackupMetadataSnapshot"
    And I wait to receive an error
    Then the backup metadata snapshot is consistent for setting "<setting>"

    Examples:
      | setting |
      | false   |
      | true    |

  # ─── SCENARIO 4: Crash-generated files retain backup metadata and are delivered (2 cases) ──
  @skip_watchos
  Scenario Outline: Crash-generated files retain backup metadata and are delivered
    Given I set the app to "backup_<setting>_crash" mode
    And I set the HTTP status code to 200
    When I run "InternalWorkingsScenario" and relaunch the crashed app
    And I set the app to "backup_<setting>_crash" mode
    And I configure Bugsnag for "InternalWorkingsScenario"
    And I wait to receive an error
    And the error is valid for the error reporting API
    And I discard all errors
    And I invoke "reportBackupMetadataSnapshot"
    And I wait to receive an error
    Then the backup metadata snapshot is consistent for setting "<setting>"

    Examples:
      | setting |
      | false   |
      | true    |

  # ─── SCENARIO 5: Full SDK lifecycle remains functional with consistent backup metadata (2 cases) ──
  @skip_watchos
  Scenario Outline: Full SDK lifecycle remains functional with consistent backup metadata
    Given I set the app to "backup_<setting>" mode
    And I set the HTTP status code to 500
    And I configure Bugsnag for "InternalWorkingsScenario"
    And I invoke "prepareBackupStorage"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    And I invoke "exerciseBackupRewrites"
    And I wait to receive an error
    And I wait for the fixture to process the response
    And I discard the oldest error
    And I kill and relaunch the app
    And I set the app to "backup_<setting>" mode
    When I configure Bugsnag for "InternalWorkingsScenario"
    And I wait to receive 2 errors
    And I discard the oldest error
    And I discard the oldest error
    And I invoke "reportBackupMetadataSnapshot"
    And I wait to receive an error
    Then the backup metadata snapshot is consistent for setting "<setting>"
    And the error is valid for the error reporting API

    Examples:
      | setting |
      | false   |
      | true    |
