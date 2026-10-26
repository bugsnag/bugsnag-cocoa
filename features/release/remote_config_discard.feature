Feature: Remote config discard rules are applied

  Background:
    Given I clear all persistent data

  Scenario: Empty remote config
    When I prepare an error config with:
     | type     | name                  | value                 	                 |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
     | header   | ETag                  | "42"                                       |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0   		 |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Invalid remote config
    When I prepare an error config with:
     | type     | name                  | value                 	                 |
     | property | body                  | @features/support/config/invalid.json      |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
     | header   | ETag                  | "42"                                       |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0   		 |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Remote config with ALL_HANDLED rule
    When I prepare an error config with:
     | type     | name                  | value                 	                      |
     | property | body                  | @features/support/config/rules_all-handled.json |
     | property | status                | 200                                             |
     | header   | Cache-Control         | max-age=604800                                  |
     | header   | ETag                  | "42"                                            |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Remote config with ALL rule
    When I prepare an error config with:
     | type     | name                  | value                 	                 |
     | property | body                  | @features/support/config/rules_all.json    |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
     | header   | ETag                  | "42"                                       |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config with ALL, ALL_HANDLED rules
    When I prepare an error config with:
     | type     | name                  | value                 	                            |
     | property | body                  | @features/support/config/rules_all_all-handled.json   |
     | property | status                | 200                                                   |
     | header   | Cache-Control         | max-age=604800                                        |
     | header   | ETag                  | "42"                                                  |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config with ALL_HANDLED, ALL rules
    When I prepare an error config with:
     | type     | name                  | value                 	                            |
     | property | body                  | @features/support/config/rules_all-handled_all.json   |
     | property | status                | 200                                                   |
     | header   | Cache-Control         | max-age=604800                                        |
     | header   | ETag                  | "42"                                                  |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config with ALL_HANDLED, unknown rules - unknown rule should not change the behaviour
    When I prepare an error config with:
     | type     | name                  | value                 	                                |
     | property | body                  | @features/support/config/rules_all-handled_unknown.json   |
     | property | status                | 200                                                       |
     | header   | Cache-Control         | max-age=604800                                            |
     | header   | ETag                  | "42"                                                      |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Remote config with HASH rule to discard specific error
    When I prepare an error config with:
     | type     | name                  | value                 	                            |
     | property | body                  | @features/support/config/rules_specific_error.json    |
     | property | status                | 200                                                   |
     | header   | Cache-Control         | max-age=604800                                        |
     | header   | ETag                  | "42"                                                  |
    And I run "RemoteConfigBasicScenario" 
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Remote config with HASH rule discards matching events and delivers non-matching
    When I prepare an error config with:
     | type     | name          | value                                          |
     | property | body          | @features/support/config/rules_hash.json       |
     | property | status        | 200                                            |
     | header   | Cache-Control | max-age=604800                                 |
     | header   | ETag          | "42"                                           |
    And I run "RemoteConfigHashScenario"
    And I wait for 1 error config to be requested
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigHashScenario"
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError        | Matches hash          |
        | NonMatchingError        | Does not match hash  |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
