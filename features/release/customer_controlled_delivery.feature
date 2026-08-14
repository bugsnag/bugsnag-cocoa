Feature: Check customer control over delivery per notify call

  Scenario: Manually mark error as fatal
    When I run "FatalErrorOptionScenario" and relaunch the crashed app
    And I configure Bugsnag for "FatalErrorOptionScenario"
    And I wait to receive 1 error
    And the event "metaData.error.reason" equals "Manually setting error as fatal"

  Scenario: Store only strategy should not send immediately
    When I run "CustomerControlledDeliveryScenario"
    And I invoke "storeOnlyStrategy"
    And I should receive no errors
    And I kill and relaunch the app
    And I configure Bugsnag for "CustomerControlledDeliveryScenario"
    And I wait to receive 1 error
    And the event "metaData.error.reason" equals "Store only type error"

  Scenario: Store and flush strategy should also send existing error files
    When I run "CustomerControlledDeliveryScenario"
    And I invoke "storeOnlyStrategy"
    And I invoke "storeOnlyStrategy"
    And I invoke "storeOnlyStrategy"
    And I invoke "storeAndFlushStrategy"
    And I wait to receive 4 errors
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 0"
    And I discard the oldest error
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 1"
    And I discard the oldest error
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 2"
    And I discard the oldest error
    And the event "metaData.error.reason" equals "Store and flush type error"
    And I discard the oldest error
    And I kill and relaunch the app
    And I configure Bugsnag for "CustomerControlledDeliveryScenario"
    And I should receive no errors

  # Skipped pending PLAT-15677
  @skip_macos_10_14
  Scenario: Store and send strategy should not send existing error files
    When I run "CustomerControlledDeliveryScenario"
    And I invoke "storeAndSendStrategy"
    And I wait to receive 1 error
    And the event "metaData.error.reason" equals "Store and send type error"
    And I discard the oldest error
    And I kill and relaunch the app
    And I configure Bugsnag for "CustomerControlledDeliveryScenario"
    And I wait to receive 3 errors
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 0"
    And I discard the oldest error
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 1"
    And I discard the oldest error
    And the event "metaData.error.reason" equals "Store only type error"
    And the event has a "log" breadcrumb named "Store number: 2"