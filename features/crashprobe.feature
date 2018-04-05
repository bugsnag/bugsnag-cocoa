Feature: Crashprobe scenarios

Scenario: Abort is reported
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "AbortScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "abort"
    And the "method" of stack frame 2 equals "-[AbortScenario run]"

Scenario: Corrupt malloc heap
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "CorruptMallocScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "abort"

Scenario: Trigger a crash after overwriting the link register
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "OverwriteLinkRegisterScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "SIGSEGV"
    And the exception "message" equals "Attempted to dereference null pointer."
    And the "method" of stack frame 0 equals "-[OverwriteLinkRegisterScenario run]"

Scenario: Attempt to write into a read-only page
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "ReadOnlyPageScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "SIGBUS"
    And the "method" of stack frame 0 equals "-[ReadOnlyPageScenario run]"

Scenario: Stack overflow is reported
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "StackOverflowScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Stack overflow in -[StackOverflowScenario run]"
    And the exception "errorClass" equals "SIGSEGV"
    And the "method" of stack frame 0 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 1 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 2 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 3 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 4 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 5 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 6 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 7 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 8 equals "-[StackOverflowScenario run]"
    And the "method" of stack frame 9 equals "-[StackOverflowScenario run]"

Scenario: Attempt to execute an instruction undefined on the current architecture
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "UndefinedInstructionScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "SIGILL"
    And the "method" of stack frame 0 equals "-[UndefinedInstructionScenario run]"

Scenario: Trigger a crash with libsystem_pthread's _pthread_list_lock held
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I configure the app to run on "iPhone 8"
    And I crash the app using "AsyncSafeThreadScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "message" equals "Attempted to dereference garbage pointer 0x1."
    And the exception "errorClass" equals "SIGSEGV"
    And the "method" of stack frame 1 equals "pthread_getname_np"
    And the "method" of stack frame 2 equals "-[AsyncSafeThreadScenario run]"

