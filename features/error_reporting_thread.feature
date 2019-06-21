Feature: Error Reporting Thread

Scenario: Only 1 thread is flagged as the error reporting thread
    When I run "HandledErrorScenario"
    And I wait for a request
    Then the request is valid for the error reporting API
    And the thread with id "0" contains the error reporting flag
