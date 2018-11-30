Feature: Reporting crash events

Scenario: Executing privileged instruction
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "PrivilegedInstructionScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[PrivilegedInstructionScenario run]"

Scenario: Calling __builtin_trap()
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "BuiltinTrapScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[BuiltinTrapScenario run]"

Scenario: Calling abort()
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
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

Scenario: Throwing a C++ exception
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "CxxExceptionScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "P16kaboom_exception"
    And the exception "type" equals "cocoa"
    And the payload field "events.0.exceptions.0.stacktrace" is an array with 0 element

Scenario: Calling non-existent method
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "NonExistentMethodScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
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

Scenario: Heap corruption by writing garbage into data areas used by malloc to track allocations
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "CorruptMallocScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And The exception reflects malloc corruption occurred

Scenario: Trigger a crash after overwriting the link register
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "OverwriteLinkRegisterScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference null pointer."
    And the "method" of stack frame 0 equals "-[OverwriteLinkRegisterScenario run]"

Scenario: Attempt to write into a read-only page
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "ReadOnlyPageScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadOnlyPageScenario run]"

Scenario: Stack overflow
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "StackOverflowScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
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
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "ObjCMsgSendScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the exception "message" equals "Attempted to dereference garbage pointer 0x42."
    And the "method" of stack frame 0 equals "objc_msgSend"

Scenario: Attempt to execute an instruction undefined on the current architecture
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "UndefinedInstructionScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "EXC_BAD_INSTRUCTION"
    And the "method" of stack frame 0 equals "-[UndefinedInstructionScenario run]"

Scenario: Send a message to an object whose memory has already been freed
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "ReleasedObjectScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
    And the "method" of stack frame 1 equals "-[ReleasedObjectScenario run]"

# N.B. this scenario is "imprecise" on CrashProbe due to line number info,
# which is not tested here as this would require symbolication
Scenario: Crash within Swift code
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "SwiftCrash"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Unexpectedly found nil while unwrapping an Optional value"
    And the exception "errorClass" equals "Fatal error"

Scenario: Assertion failure in Swift code
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "SwiftAssertion"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "errorClass" equals "Fatal error"
    And the exception "message" equals "several unfortunate things just happened"

Scenario: Dereference a null pointer
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "NullPointerScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Attempted to dereference null pointer."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[NullPointerScenario run]"

Scenario: Trigger a crash with libsystem_pthread's _pthread_list_lock held
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "AsyncSafeThreadScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the "Bugsnag-API-Key" header equals "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And the payload field "notifier.name" equals "iOS Bugsnag Notifier"
    And the payload field "events" is an array with 1 element
    And the exception "message" equals "Attempted to dereference garbage pointer 0x1."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 1 equals "pthread_getname_np"
    And the "method" of stack frame 2 equals "-[AsyncSafeThreadScenario run]"

Scenario: Read a garbage pointer
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "ReadGarbagePointerScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" starts with "Attempted to dereference garbage pointer"
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "-[ReadGarbagePointerScenario run]"

Scenario: Throw a NSException
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "ObjCExceptionScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "An uncaught exception! SCREAM."
    And the exception "errorClass" equals "NSGenericException"
    And the "method" of stack frame 0 equals "__exceptionPreprocess"
    And the "method" of stack frame 1 equals "objc_exception_throw"
    And the "method" of stack frame 2 equals "-[ObjCExceptionScenario run]"

Scenario: Access a non-object as an object
    When I set environment variable "BUGSNAG_API_KEY" to "a35a2a72bd230ac0aa0f52715bbdc6aa"
    And I crash the app using "AccessNonObjectScenario"
    And I relaunch the app
    Then I should receive a request
    And the request is a valid for the error reporting API
    And the exception "message" equals "Attempted to dereference garbage pointer 0x10."
    And the exception "errorClass" equals "EXC_BAD_ACCESS"
    And the "method" of stack frame 0 equals "objc_msgSend"
