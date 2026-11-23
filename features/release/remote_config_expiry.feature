Feature: Remote config error-first cache behavior

  Background:
    Given I clear all persistent data

  Scenario: Fresh remote config does not require another request
    When I prepare an error config with:
     | type     | name          | value                                 |
     | property | body          | @features/support/config/no_rules.json |
     | property | status        | 200                                   |
     | header   | Cache-Control | max-age=604800                        |
     | header   | ETag          | "fresh-config"                        |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass       | exceptions.0.message |
        | RemoteConfigExpiryError       | Err 0                |
        | RemoteConfigExpiryError       | Err 1                |
        | RemoteConfigExpiryError       | Err 2                |
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

  Scenario: Expired config refreshes after a successful fetch
    When I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=4                               |
     | header   | ETag          | "short-lived-config"                    |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I wait to receive 3 errors
    # A successful fetch does not start a cooldown, so each expiry allows a refresh
    And I wait to receive between 2 and 3 error config requests
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
        | RemoteConfigExpiryError | Err 2                |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error

  Scenario: Cooldown prevents a retry after a failed config request
    When I prepare an error config with:
     | type     | name   | value |
     | property | status | 500   |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I make the test fixture wait for 1 second
    And I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=604800                          |
     | header   | ETag          | "should-not-be-fetched"                 |
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
        | RemoteConfigExpiryError | Err 2                |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error

  Scenario: Cooldown after a failed config request persists across a relaunch
    When I prepare an error config with:
     | type     | name   | value |
     | property | status | 503   |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I wait to receive 3 errors
    And I discard all errors
    And I discard the oldest error config request
    And I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=604800                          |
     | header   | ETag          | "should-not-be-fetched"                 |
    And I kill and relaunch the app
    And I run "RemoteConfigExpiryScenario"
    # Errors are still delivered without discard rules while the persisted cooldown is active
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
        | RemoteConfigExpiryError | Err 2                |
    Then I should receive no error config requests

  Scenario: App upgrade during an active cooldown fetches fresh config
    When I prepare an error config with:
     | type     | name   | value |
     | property | status | 503   |
    And I set the app to "1.0" mode
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I wait to receive 3 errors
    And I discard all errors
    And I discard the oldest error config request
    And I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=604800                          |
     | header   | ETag          | "v2-config"                             |
    And I kill and relaunch the app
    And I set the app to "2.0" mode
    And I run "RemoteConfigExpiryScenario"
    # The 1.0 cooldown does not apply to 2.0, so the first error triggers a fetch
    And I wait for 1 error config to be requested
    And I wait to receive 1 error
    And the error payload field "events.0.exceptions.0.message" equals "Err 0"
    And the error payload field "events.0.app.version" equals "2.0"
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Expired no-rules config is replaced by an ALL rule
    When I prepare an error config with:
     | type     | name          | value                                 |
     | property | body          | @features/support/config/no_rules.json |
     | property | status        | 200                                   |
     | header   | Cache-Control | max-age=4                             |
     | header   | ETag          | "no-rules"                            |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I make the test fixture wait for 1 second
    And I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=100                            |
     | header   | ETag          | "all-rules"                            |
    And I wait to receive 2 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
    Then the error is valid for the error reporting API
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And I discard the oldest error
    Then I should receive no errors

  Scenario: Expired ALL config is replaced by no rules
    When I prepare an error config with:
     | type     | name          | value                                   |
     | property | body          | @features/support/config/rules_all.json |
     | property | status        | 200                                     |
     | header   | Cache-Control | max-age=4                               |
     | header   | ETag          | "all-rules"                             |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I make the test fixture wait for 1 second
    And I prepare an error config with:
     | type     | name          | value                                 |
     | property | body          | @features/support/config/no_rules.json |
     | property | status        | 200                                   |
     | header   | Cache-Control | max-age=100                           |
     | header   | ETag          | "no-rules"                            |
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
        | RemoteConfigExpiryError | Err 2                |

  Scenario: Expired no-rules config is refreshed by a 304 response
    When I prepare an error config with:
     | type     | name          | value                                 |
     | property | body          | @features/support/config/no_rules.json |
     | property | status        | 200                                   |
     | header   | Cache-Control | max-age=4                             |
     | header   | ETag          | "no-rules"                            |
    And I run "RemoteConfigExpiryScenario"
    And I wait for 1 error config to be requested
    And I make the test fixture wait for 1 second
    And I prepare an error config with:
     | type     | name          | value       |
     | property | status        | 304         |
     | header   | Cache-Control | max-age=100 |
     | header   | ETag          | "no-rules" |
    And I wait to receive 3 errors
    And the received errors match:
        | exceptions.0.errorClass | exceptions.0.message |
        | RemoteConfigExpiryError | Err 0                |
        | RemoteConfigExpiryError | Err 1                |
        | RemoteConfigExpiryError | Err 2                |
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
    Then the error is valid for the error reporting API
    And the event "unhandled" is false
    And I discard the oldest error
