@stress_test
Feature: Stress test

  Scenario: Triggering error notifications continuously
    When I start a new shell
    And I input "cd features/fixtures/macos-stress-test" interactively
    And I input "make build run" interactively
    And I wait for the shell to output "macOS stress-test complete" to stdout
    Then the last interactive command exited successfully

    # This is low, but due to network congestion all we can guarantee in the course of a normal test
    And I have received at least 1 error
