Feature: Out of memory events

    Scenario: The OS kills the application while inactive
        The application is in the foreground but inactive when interrupted 
        by a phone call or Siri

        When I run "OOMScenario"
        And the app is interrupted by Siri
        And the app is unexpectedly terminated
        And I relaunch the app
        And I wait for 10 seconds
        Then I should receive 0 requests
