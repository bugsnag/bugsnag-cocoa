Feature: Reporting crash events

Background:
    Given I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"

Scenario: Executing privileged instruction
    When I crash the app using "PrivilegedInstructionScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[PrivilegedInstructionScenario run]"

Scenario: Calling __builtin_trap()
    When I crash the app using "BuiltinTrapScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[BuiltinTrapScenario run]"

Scenario: Calling abort()
    When I crash the app using "AbortScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "SIGABRT"
    And the "method" of stack frame 0 equals "__pthread_kill"
    And the "method" of stack frame 1 equals "abort"
    And the "method" of stack frame 2 equals "-[AbortScenario run]"

Scenario: Throwing a C++ exception
    When I crash the app using "CxxExceptionScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "P16kaboom_exception"
    And the exception "type" equals "cocoa"
    And the payload field "events.0.exceptions.0.stacktrace" is an array with 0 element

Scenario: Calling non-existent method
    When I crash the app using "NonExistentMethodScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "message" starts with "-[NonExistentMethodScenario santaclaus:]: unrecognized selector sent to instance"
    And the exception "errorClass" equals "NSInvalidArgumentException"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[NSObject(NSObject) doesNotRecognizeSelector:]"
    And the "method" of stack frame 3 equals "___forwarding___"
    And the "method" of stack frame 4 equals "_CF_forwarding_prep_0"
    And the "method" of stack frame 5 equals "-[NonExistentMethodScenario run]"

Scenario: Trigger a crash after overwriting the link register
    When I crash the app using "OverwriteLinkRegisterScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference null pointer."
    And the "method" of stack frame 0 equals "-[OverwriteLinkRegisterScenario run]"

Scenario: Attempt to write into a read-only page
    When I crash the app using "ReadOnlyPageScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadOnlyPageScenario run]"

Scenario: Stack overflow
    When I crash the app using "StackOverflowScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "Stack overflow in -[StackOverflowScenario run]"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
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

Scenario: Crash inside objc_msgSend()
    When I crash the app using "ObjCMsgSendScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference garbage pointer 0x42."
    And the "method" of stack frame 0 equals "objc_msgSend"

Scenario: Attempt to execute an instruction undefined on the current architecture
    When I crash the app using "UndefinedInstructionScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[UndefinedInstructionScenario run]"

Scenario: Send a message to an object whose memory has already been freed
    When I crash the app using "ReleasedObjectScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
    And the "method" of stack frame 1 equals "-[ReleasedObjectScenario run]"

# N.B. this scenario is "imprecise" on CrashProbe due to line number info,
# which is not tested here as this would require symbolication
Scenario: Crash within Swift code
    When I crash the app using "SwiftCrash"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" contains "Unexpectedly found nil while unwrapping an Optional value"
    And the exception "errorClass" equals "Fatal error"

Scenario: Assertion failure in Swift code
    When I crash the app using "SwiftAssertion"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "errorClass" equals "Fatal error"
    And the exception "message" contains "several unfortunate things just happened"

Scenario: Dereference a null pointer
    When I crash the app using "NullPointerScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "Attempted to dereference null pointer."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[NullPointerScenario run]"

Scenario: Trigger a crash with libsystem_pthread's _pthread_list_lock held
    When I crash the app using "AsyncSafeThreadScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "message" equals "Attempted to dereference garbage pointer 0x1."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the stacktrace contains methods:
    |pthread_getname_np|
    |-[AsyncSafeThreadScenario run]|

Scenario: Read a garbage pointer
    When I crash the app using "ReadGarbagePointerScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadGarbagePointerScenario run]"

Scenario: Throw a NSException
    When I crash the app using "ObjCExceptionScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "An uncaught exception! SCREAM."
    And the exception "errorClass" equals "NSGenericException"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[ObjCExceptionScenario run]"
    And the event "device.time" is within 60 seconds of the current timestamp

Scenario: Access a non-object as an object
    When I crash the app using "AccessNonObjectScenario"
    And I relaunch the app
    And I wait for a request
    Then the request is valid for the error reporting API
    And the exception "message" equals "Attempted to dereference garbage pointer 0x10."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
