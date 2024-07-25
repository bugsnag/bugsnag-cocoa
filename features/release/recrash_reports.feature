Feature: Detection of crashes during crash handling

  KSCrash can detect when a crash has occurred while executing its crash handler.
  Since any of the sentries could have bugs which would stop this mechanism working,
  they all need to be tested.

  Background:
    Given I clear all persistent data

  Scenario Outline: An internal error report is sent if onCrashHandler crashes
    Given I run "<scenario>" and relaunch the crashed app
    And I configure Bugsnag for "<scenario>"
    And I wait to receive an error
    And the error "Bugsnag-Api-Key" header is not present
    And the error "Bugsnag-Internal-Error" header equals "bugsnag-cocoa"
    And the error payload field "events.0.threads" is an array with 0 elements
    And the event "metaData.BugsnagDiagnostics.apiKey" equals "12312312312312312312312312312312"
    And the event "apiKey" is null
    And the event "unhandled" is true
    And the exception "errorClass" equals "Crash handler crashed"
    And the exception "message" equals "<message>"
    And the "method" of stack frame 0 matches "OnCrashBadAccess|__pthread_kill"
    Examples:
      | scenario                    | message        |
      | RecrashCppMachScenario      | EXC_BAD_ACCESS |
      | RecrashCppSignalScenario    | SIGABRT        |
      | RecrashMachMachScenario     | EXC_BAD_ACCESS |
      | RecrashMachSignalScenario   | SIGABRT        |
      | RecrashObjcMachScenario     | EXC_BAD_ACCESS |
      | RecrashObjcSignalScenario   | SIGABRT        |
      | RecrashSignalSignalScenario | SIGABRT        |

  # A crashing signal handler on iOS 12 / macOS 10.14 and earlier will deadlock
  # in the kernel and fail the "I wait to receive an error" step.
  @skip_below_ios_13
  @skip_below_macos_10_15
  Scenario Outline: An internal error report is sent if onCrashHandler crashes
    Given I run "RecrashSignalMachScenario" and relaunch the crashed app
    And I configure Bugsnag for "RecrashSignalMachScenario"
    And I wait to receive an error
    And the exception "errorClass" equals "Crash handler crashed"
    And the exception "message" equals "EXC_BAD_ACCESS"
