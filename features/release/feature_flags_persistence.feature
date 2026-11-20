Feature: Feature flag persistence

  # Feature flags are persisted in <storage>/featureFlags/featureflag.bin so that they can be included in
  # Out Of Memory / thermal kill events at next launch. Older SDKs persisted one JSON file per flag.
  # Nothing is created in the directory (neither featureflag.bin nor featureflag.lock) until there are
  # flags to save, so an app that never has feature flags leaves it empty. When all flags are cleared,
  # an existing file is emptied in place. Adding a flag that is already present replaces its variant
  # and keeps its position, in memory and in the file.
  #
  # Handled errors use the in-memory flags and crash reports use the crash-safe atomic store, so only
  # OOM events (iOS only, tagged @skip_macos) report the flags read back from disk.
  #
  # Scenarios based on FeatureFlagsPersistenceScenario add "flagsDir" metadata describing the
  # featureFlags directory when the event is sent, and "flagsDirBeforeStart" describing it before
  # Bugsnag was started in that launch.

  Background:
    Given I clear all persistent data

  # 1
  Scenario: Adding, overwriting and clearing flags behaves as before
    When I run "FeatureFlagsAPIBehaviourScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | flag-a      | a2             |
      | flag-b      | b1             |
      | flag-c      |                |
      | flag-d      | d1             |
    # Overwriting a flag keeps its position
    And the event "featureFlags.0.featureFlag" equals "config-flag"
    And the event "featureFlags.1.featureFlag" equals "flag-a"
    And the event "featureFlags.2.featureFlag" equals "flag-b"
    And the event "featureFlags.3.featureFlag" equals "flag-c"
    And the event "featureFlags.4.featureFlag" equals "flag-d"

  # 2
  Scenario: Bulk-added, updated and cleared flags are included in a crash report
    When I run "FeatureFlagsBulkCrashScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsBulkCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the event "unhandled" is true
    And the error payload field "events.0.featureFlags" is an array with 499 elements
    And every feature flag in the event has a variant starting with its name and ":"
    And the event contains the feature flag "bulk-000" with variant "bulk-000:v1"
    And the event contains the feature flag "bulk-123" with variant "bulk-123:updated"
    And the event contains the feature flag "bulk-499" with variant "bulk-499:v1"
    And the event does not contain the feature flag "bulk-456"

  # 3
  Scenario: Clearing all flags before a crash reports no flags
    When I run "FeatureFlagsClearAllCrashScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsClearAllCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "NSGenericException"
    And the exception "message" equals "FeatureFlagsClearAllCrashScenario"
    And the event has no feature flags

  # 4
  Scenario: Long and Unicode names, empty and nil variants are reported without truncation
    When I run "FeatureFlagsUnusualValuesScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsUnusualValuesScenario"
    And I wait to receive 2 errors

    # Handled error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And the error payload field "events.0.featureFlags" is an array with 4 elements
    And the event "featureFlags.0.featureFlag" matches "^long-name-n{300}-end$"
    And the event "featureFlags.0.variant" matches "^long-variant-v{300}-end$"
    And the event "featureFlags.1.featureFlag" equals "🚩 機能フラグ/功能标志/флаг"
    And the event "featureFlags.1.variant" equals "变体-🎉-ヴァリアント"
    And the event contains the feature flag "empty-variant" with variant ""
    And the event contains the feature flag "nil-variant" with no variant
    And I discard the oldest error

    # Crash report
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
    And the exception "message" equals "FeatureFlagsUnusualValuesScenario"
    And the error payload field "events.0.featureFlags" is an array with 4 elements
    And the event "featureFlags.0.featureFlag" matches "^long-name-n{300}-end$"
    And the event "featureFlags.0.variant" matches "^long-variant-v{300}-end$"
    And the event "featureFlags.1.featureFlag" equals "🚩 機能フラグ/功能标志/флаг"
    And the event "featureFlags.1.variant" equals "变体-🎉-ヴァリアント"
    And the event contains the feature flag "empty-variant" with variant ""
    And the event contains the feature flag "nil-variant" with no variant

  # 5
  Scenario: Flags changed by several threads while the app crashes are well-formed
    When I run "FeatureFlagsConcurrentCrashScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsConcurrentCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the error payload field "events.0.featureFlags" is a non-empty array
    And every feature flag in the event has a variant starting with its name and ":"
    And the event contains the feature flag "config-flag" with variant "config-flag:config"
    And the event contains the feature flag "main-flag" with variant "main-flag:0"

  # 6
  Scenario: Flags from a previous launch are not reported
    When I run "FeatureFlagsRelaunchScenario"
    And I wait to receive an error
    And I discard the oldest error
    And I kill and relaunch the app
    And I run "FeatureFlagsRelaunchScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | new         | launch2        |

  # 6 (OOM)
  @skip_macos
  Scenario: Flags from a previous launch are not reported in an OOM event
    When I run "FeatureFlagsRelaunchOOMScenario" and relaunch the crashed app
    And I run "FeatureFlagsRelaunchOOMScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsRelaunchOOMScenario"
    And I wait to receive 2 errors

    # Launch 1
    Then the error is an OOM event
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | old         | launch1        |
    And I discard the oldest error

    # Launch 2
    Then the error is an OOM event
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | new         | launch2        |

  # 7 (also covers 2 and 4 for the persisted file)
  @skip_macos
  Scenario: OOM events contain bulk-added, updated, long, Unicode, empty-variant and nil-variant flags
    When I run "FeatureFlagsOOMScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsOOMScenario"
    And I wait to receive an error
    Then the error is an OOM event
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    And the event "metaData.flagsDir.jsonFileCount" equals 0
    # config-flag + 499 bulk flags (bulk-123 keeps its position when updated) + 4 others
    And the error payload field "events.0.featureFlags" is an array with 504 elements
    And the event "featureFlags.0.featureFlag" equals "config-flag"
    And the event "featureFlags.0.variant" equals "config-flag:config"
    And the event "featureFlags.1.featureFlag" equals "bulk-000"
    And the event "featureFlags.1.variant" equals "bulk-000:v1"
    And the event "featureFlags.123.featureFlag" equals "bulk-122"
    And the event "featureFlags.123.variant" equals "bulk-122:v1"
    And the event "featureFlags.124.featureFlag" equals "bulk-123"
    And the event "featureFlags.124.variant" equals "bulk-123:updated"
    And the event "featureFlags.125.featureFlag" equals "bulk-124"
    And the event "featureFlags.125.variant" equals "bulk-124:v1"
    And the event "featureFlags.456.featureFlag" equals "bulk-455"
    And the event "featureFlags.457.featureFlag" equals "bulk-457"
    And the event "featureFlags.499.featureFlag" equals "bulk-499"
    And the event "featureFlags.499.variant" equals "bulk-499:v1"
    And the event does not contain the feature flag "bulk-456"
    And the event "featureFlags.500.featureFlag" matches "^long-name-n{300}-end$"
    And the event "featureFlags.500.variant" matches "^long-variant-v{300}-end$"
    And the event "featureFlags.501.featureFlag" equals "🚩 機能フラグ/功能标志/флаг"
    And the event "featureFlags.501.variant" equals "变体-🎉-ヴァリアント"
    And the event "featureFlags.502.featureFlag" equals "empty-variant"
    And the event contains the feature flag "empty-variant" with variant ""
    And the event "featureFlags.503.featureFlag" equals "nil-variant"
    And the event contains the feature flag "nil-variant" with no variant

  # 8 (OOM)
  @skip_macos
  Scenario: Flags stored as JSON files by an older SDK are reported in an OOM event after upgrading
    # Launch 1 replaces featureflag.bin with legacy JSON files after Bugsnag has started, then is killed
    When I run "FeatureFlagsLegacyUpgradeOOMScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsLegacyUpgradeOOMScenario"
    And I wait to receive an error
    Then the error is an OOM event
    And the event "metaData.flagsDirBeforeStart.featureFlagFileExists" is false
    And the event "metaData.flagsDirBeforeStart.jsonFileCount" equals 5
    # The legacy files are imported in index order, and then deleted
    And the error payload field "events.0.featureFlags" is an array with 5 elements
    And the event "featureFlags.0.featureFlag" equals "legacy-first"
    And the event "featureFlags.0.variant" equals "first"
    And the event "featureFlags.1.featureFlag" equals "legacy-a"
    And the event contains the feature flag "legacy-a" with no variant
    And the event "featureFlags.2.featureFlag" equals "legacy-b"
    And the event "featureFlags.2.variant" equals "variant-b"
    And the event "featureFlags.3.featureFlag" equals "legacy flag/ü 🚩"
    And the event "featureFlags.3.variant" equals "unicode-variant"
    And the event "featureFlags.4.featureFlag" equals "legacy-empty"
    And the event contains the feature flag "legacy-empty" with variant ""
    And the event "metaData.flagsDir.jsonFileCount" equals 0
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true

  # 8
  Scenario: Flags stored as JSON files by an older SDK are migrated to featureflag.bin
    When I run "FeatureFlagsLegacyMigrationScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.flagsDirBeforeStart.featureFlagFileExists" is false
    And the event "metaData.flagsDirBeforeStart.jsonFileCount" equals 3
    And the event "metaData.flagsDir.jsonFileCount" equals 0
    And the event "metaData.flagsDir.featureFlagFileExists" is true
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    And the event contains the following feature flags:
      | featureFlag | variant         |
      | config-flag | config-variant  |
      | current     | current-variant |

  # 9
  Scenario: Stale JSON flag files next to featureflag.bin are deleted
    When I run "FeatureFlagsStaleJSONScenario"
    And I wait to receive an error
    And I discard the oldest error
    And I kill and relaunch the app
    And I run "FeatureFlagsStaleJSONScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.flagsDirBeforeStart.featureFlagFileExists" is true
    And the event "metaData.flagsDirBeforeStart.jsonFileCount" equals 2
    And the event "metaData.flagsDir.jsonFileCount" equals 0
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    And the event contains the following feature flags:
      | featureFlag  | variant        |
      | config-flag  | config-variant |
      | launch2-flag | launch2        |

  # 9 (OOM)
  @skip_macos
  Scenario: Flags are not reported in an OOM event when featureflag.bin and JSON files are found together, and the JSON files are deleted
    When I run "FeatureFlagsStaleJSONOOMScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsStaleJSONOOMScenario"
    And I wait to receive an error
    Then the error is an OOM event
    And the event "metaData.flagsDirBeforeStart.featureFlagFileExists" is true
    And the event "metaData.flagsDirBeforeStart.jsonFileCount" equals 2
    And the event "metaData.flagsDir.jsonFileCount" equals 0
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    # featureflag.bin and JSON files found together are both discarded
    And the event has no feature flags

  # 10
  Scenario Outline: A corrupt featureflag.bin does not prevent flags being reported
    When I set the app to "<mode>" mode
    And I run "FeatureFlagsCorruptFileScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "metaData.flagsDirBeforeStart.featureFlagFileExists" is true
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | after-start | current        |
      | bulk-000    | bulk-000:v1    |
      | bulk-002    | bulk-002:v1    |

    Examples:
      | mode          |
      | random        |
      | badSnapshot   |
      | truncated     |
      | empty         |
      | futureVersion |

  # 10 (OOM)
  @skip_macos
  Scenario Outline: A corrupt featureflag.bin does not prevent flags being reported in an OOM event
    When I set the app to "<mode>" mode
    And I run "FeatureFlagsCorruptFileOOMScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsCorruptFileOOMScenario"
    And I wait to receive an error
    Then the error is an OOM event
    And the event contains the following feature flags:
      | featureFlag | variant        |
      | config-flag | config-variant |
      | after-start | current        |
      | bulk-000    | bulk-000:v1    |
      | bulk-002    | bulk-002:v1    |

    Examples:
      | mode          |
      | random        |
      | badSnapshot   |
      | truncated     |

  # 11
  Scenario: A directory at the featureflag.bin path does not prevent flags being reported in a handled error
    When I run "FeatureFlagsDirectoryAtFilePathScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And the event "metaData.flagsDirBeforeStart.featureFlagFileIsDirectory" is true
    And the event contains the following feature flags:
      | featureFlag | variant          |
      | config-flag | config-variant   |
      | after-start | current          |
      | bulk-000    | bulk-000:updated |
      | bulk-002    | bulk-002:v1      |

  # 11
  Scenario: A directory at the featureflag.bin path does not prevent flags being reported in a crash report
    When I run "FeatureFlagsDirectoryAtFilePathCrashScenario" and relaunch the crashed app
    And I configure Bugsnag for "FeatureFlagsDirectoryAtFilePathCrashScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
    And the exception "message" equals "FeatureFlagsDirectoryAtFilePathCrashScenario"
    And the event "metaData.flagsDirBeforeStart.featureFlagFileIsDirectory" is true
    And the event contains the following feature flags:
      | featureFlag | variant          |
      | config-flag | config-variant   |
      | after-start | current          |
      | bulk-000    | bulk-000:updated |
      | bulk-002    | bulk-002:v1      |

  # 12
  Scenario: Nothing is created in the feature flags directory when there are no flags
    When I run "FeatureFlagsNoFlagsScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event has no feature flags
    And the event "metaData.flagsDir.featureFlagFileExists" is false
    And the event "metaData.flagsDir.lockFileExists" is false
    And the event "metaData.flagsDir.jsonFileCount" equals 0

  # 12
  Scenario: Clearing all flags empties featureflag.bin
    When I set the app to "add-clear" mode
    And I run "FeatureFlagsNoFlagsScenario"
    And I wait to receive an error
    Then the error is valid for the error reporting API
    And the event has no feature flags
    And the event "metaData.flagsDir.featureFlagFileExists" is true
    And the event "metaData.flagsDir.featureFlagFileHasValidHeader" is true
    And the event "metaData.flagsDir.lockFileExists" is true
