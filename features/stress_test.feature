@stress_test
Feature: Stress test

  Scenario: Triggering error notifications continuously
    When I start a new shell
    And I input "./features/fixtures/macos-stress-test/run.sh" interactively
    And I wait for the shell to output a match for the regex "BugsnagStressTest exited with " to stdout
    And the shell has output "BugsnagStressTest exited with 0" to stdout

    # This is low, but due to network congestion all we can guarantee in the course of a normal test
    And I have received at least 1 error
