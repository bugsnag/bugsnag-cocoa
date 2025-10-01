Feature: Remote config discard rules are applied

  Background:
    Given I clear all persistent data

  Scenario: Empty remote config
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
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
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/invalid.json      |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
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
     | type     | name                  | value                 	                  |
     | property | body                  | @features/support/config/rules_all-handled.json |
     | property | status                | 200                                             |
     | header   | Cache-Control         | max-age=604800                                  |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true

  Scenario: Remote config with ALL rule
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/rules_all.json    |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    Then I should receive no errors

  Scenario: Remote config with ALL, ALL_HANDLED rules
    When I prepare an error config with:
     | type     | name                  | value                 	                        |
     | property | body                  | @features/support/config/rules_all_all-handled.json   |
     | property | status                | 200                                                   |
     | header   | Cache-Control         | max-age=604800                                        |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    Then I should receive no errors

  Scenario: Remote config with ALL_HANDLED, ALL rules
    When I prepare an error config with:
     | type     | name                  | value                 	                        |
     | property | body                  | @features/support/config/rules_all-handled_all.json   |
     | property | status                | 200                                                   |
     | header   | Cache-Control         | max-age=604800                                        |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    Then I should receive no errors

  Scenario: Remote config with ALL_HANDLED, unknown rules - unknown rule should not change the behaviour
    When I prepare an error config with:
     | type     | name                  | value                 	                            |
     | property | body                  | @features/support/config/rules_all-handled_unknown.json   |
     | property | status                | 200                                                       |
     | header   | Cache-Control         | max-age=604800                                            |
    And I run "RemoteConfigBasicScenario" 
    And on macOS, I wait for 10 seconds
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigBasicScenario"
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "severity" equals "error"
    And the event "unhandled" is true
