Feature: Remote config discard rules are applied

  Background:
    Given I clear all persistent data

  Scenario: Remote config does not expire
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=604800                             |
    And I run "RemoteConfigExpiryScenario"
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message   |
        | RemoteConfigExpiryError       | Err 0   		 |
        | RemoteConfigExpiryError       | Err 1   		 |
        | RemoteConfigExpiryError       | Err 2   		 |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error

  Scenario: Remote config expire from no rules to all
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=4                                  |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 2 seconds
    And I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/rules_all.json    |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=100                                |
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message   |
        | RemoteConfigExpiryError       | Err 0   		 |
        | RemoteConfigExpiryError       | Err 1   		 |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config expire from all to no rules
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/rules_all.json    |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=4                                  |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 2 seconds
    And I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=100                                |
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message   |
        | RemoteConfigExpiryError       | Err 1   		 |
        | RemoteConfigExpiryError       | Err 2   		 |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config expire from all to not modified
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/rules_all.json    |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=4                                  |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 2 seconds
    And I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | status                | 304                                        |
     | header   | Cache-Control         | max-age=100                                |
     | header   | ETag                  | 34707c7a958213a2e070b257a3ae983651866e89   |
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message   |
        | RemoteConfigExpiryError       | Err 1   		 |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Remote config expire from no rules to not modified
    When I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | body                  | @features/support/config/no_rules.json     |
     | property | status                | 200                                        |
     | header   | Cache-Control         | max-age=4                                  |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 2 seconds
    And I prepare an error config with:
     | type     | name                  | value                 	             |
     | property | status                | 304                                        |
     | header   | Cache-Control         | max-age=100                                |
     | header   | ETag                  | 85cf62136c5d93a0b33bb69bdfe5f734b4530263   |
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message   |
        | RemoteConfigExpiryError       | Err 0   		 |
        | RemoteConfigExpiryError       | Err 1   		 |
        | RemoteConfigExpiryError       | Err 2   		 |
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "severity" equals "warning"
    And the event "unhandled" is false
    And I discard the oldest error

  Scenario: Expired config is invalidated and replaced by new config
    When I prepare an error config with:
     | type     | name          | value                                     |
     | property | body          | @features/support/config/rules_all.json   |
     | property | status        | 200                                       |
     | header   | Cache-Control | max-age=1                                 |
     | header   | ETag          | "42"                                      |
    And I run "RemoteConfigCacheExpiryScenario"
    And I wait for 1 error config to be requested
    And I wait for 3 seconds
    And I prepare an error config with:
     | type     | name          | value                                     |
     | property | body          | @features/support/config/no_rules.json    |
     | property | status        | 200                                       |
     | header   | Cache-Control | max-age=604800                            |
     | header   | ETag          | "43"                                      |
    And I wait for 1 error config to be requested
    And I wait to receive an error
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false

  Scenario: Server error does not block delivery; nil endpoint disables config and deletes stored
    When I prepare an error config with:
     | type     | name          | value                                     |
     | property | body          | @features/support/config/no_rules.json    |
     | property | status        | 200                                       |
     | header   | Cache-Control | max-age=604800                            |
     | header   | ETag          | "42"                                      |
    And I run "RemoteConfigBasicScenario"
    And I wait for 1 error config to be requested
    And on macOS, I wait for 10 seconds
    And I prepare an error config with:
     | type     | name   | value |
     | property | status | 500   |
    And I relaunch the app after a crash
    And I configure Bugsnag for "RemoteConfigOptOutScenario"
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigError       | Err 0                |
        | NSGenericException      | Uncaught exception!  |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is true
