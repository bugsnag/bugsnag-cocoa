@stress_test
Feature: Stress test

  Scenario: Triggering error notifications continuously
    When I start a new shell
    And I input "cd features/fixtures/macos-stress-test" interactively
    And I input "make build run" interactively
    And I wait for 180 seconds
    And I wait for the shell to output "MacOS stress-test complete" to stdout
    Then the last interactive command exited successfully
    And I have received at least 1000 error requests
