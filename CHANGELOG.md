Changelog
=========

## TBD

### Enhancements

* Persist breadcrumbs on disk to allow reading upon next boot in the event of an
  uncatchable app termination.
* Add `+[Bugsnag appDidCrashLastLaunch]` as a helper to determine if the
  previous launch of the app ended in a crash or otherwise unexpected termination.

## 5.19.1 (2019-03-27)

### Bug fixes

* Fix generating an incorrect stacktrace used when logging an exception to
  Bugsnag from a location other than the original call site (for example, from a
  logging function or across threads).  If an exception was raised/thrown, then
  the resulting Bugsnag report from `notify()` will now use the `NSException`
  instance's call stack addresses to construct the stacktrace, ignoring depth.
  This fixes an issue in macOS exception reporting where `reportException` is
  reporting the handler code stacktrace rather than the reported exception
  stack.
  [#334](https://github.com/bugsnag/bugsnag-cocoa/pull/334)

* Fix network connectivity monitor by connecting to the correct domain
  [Jacky Wijaya](https://github.com/Jekiwijaya)
  [#332](https://github.com/bugsnag/bugsnag-cocoa/pull/332)

## 5.19.0 (2019-02-28)

Note for Carthage users: this release updates the Xcode configuration to the settings recommended by Xcode 10.

* Update workspace to recommended settings suggested by XCode 10
  [#324](https://github.com/bugsnag/bugsnag-cocoa/pull/324)

### Enhancements

* Add stopSession() and resumeSession() to Bugsnag
  [#325](https://github.com/bugsnag/bugsnag-cocoa/pull/325)

## 5.18.0 (2019-02-21)

### Enhancements

* Capture basic report diagnostics in the file path in case of crash report
  content corruption
  [#327](https://github.com/bugsnag/bugsnag-cocoa/pull/327)

## 5.17.3 (2018-12-19)

### Bug Fixes

* Fix case where notify() causes an unhandled report
  [#322](https://github.com/bugsnag/bugsnag-cocoa/pull/322)

* Fix possible crash when fetching system info to append to a crash report
  [#321](https://github.com/bugsnag/bugsnag-cocoa/pull/321)

## 5.17.2 (2018-12-05)

* Add Device time of report capture to JSON payload
  [#315](https://github.com/bugsnag/bugsnag-cocoa/pull/315)

## 5.17.1 (2018-11-29)

### Bug Fixes

* Fix stack trace resolution on iPhone XS sometimes reporting incorrect
  addresses
  [#319](https://github.com/bugsnag/bugsnag-cocoa/pull/319)

* Add `fatalError` and other assertion failure messages in reports for
  Swift 4.2 apps. Note that this only includes messages which are 16
  characters or longer. See the linked pull request for more information.
  [#320](https://github.com/bugsnag/bugsnag-cocoa/pull/320)

## 5.17.0 (2018-09-25)

### Enhancements

* Capture trace of error reporting thread and identify with boolean flag
  [#303](https://github.com/bugsnag/bugsnag-cocoa/pull/303)

### Bug Fixes

* Prevent potential crash in session delivery during app teardown
  [#308](https://github.com/bugsnag/bugsnag-cocoa/pull/308)


## 5.16.4 (13 Sept 2018)

### Bug Fixes

* Ensure NSException is captured when handler is overridden
  [#313](https://github.com/bugsnag/bugsnag-cocoa/pull/313)

* Fix mach handler declaration and imports. This resolves an issue where signal
  codes were less specific than is possible.
  [#314](https://github.com/bugsnag/bugsnag-cocoa/pull/314)

* Only call previously installed C++ termination handler if non-null. Fixes an
  unexpected termination if you override the handler with null before
  initializing Bugsnag and then throw a C++ exception and would like the app to
  continue after Bugsnag completes exception reporting.


## 5.16.3 (14 Aug 2018)

### Bug Fixes

* Deregister notification observers and listeners before application termination [#301](https://github.com/bugsnag/bugsnag-cocoa/pull/301)

## 5.16.2 (17 Jul 2018)

### Bug fixes

* Fix a regression in session tracking where app version was set to nil
  [#296](https://github.com/bugsnag/bugsnag-cocoa/pull/296)

* Fix a regression in session tracking which caused the first session HTTP
  request to be delivered on the calling thread when automatic session tracking
  is enabled
  [#295](https://github.com/bugsnag/bugsnag-cocoa/pull/295)

## 5.16.1 (11 Jul 2018)

### Bug Fixes

* Respect appVersion override when serialising KSCrash report [#292](https://github.com/bugsnag/bugsnag-cocoa/pull/292)

## 5.16.0 (02 Jul 2018)

This release alters the behaviour of the notifier to track sessions automatically.
A session will be automatically captured on each app launch and sent to [https://sessions.bugsnag.com](https://sessions.bugsnag.com).

If you use Bugsnag On-Premise, it is now also recommended that you set your notify and session endpoints via `config.setEndpoints(notify:sessions:)`. The previous properties used to configure this, `config.notifyURL` and `config.sessionURL`, are now `readonly` and therefore no longer assignable.

* Enable automatic session tracking by default [#286](https://github.com/bugsnag/bugsnag-cocoa/pull/286)

### Bug Fixes

* Handle potential nil content value in RegisterErrorData class [#289](https://github.com/bugsnag/bugsnag-cocoa/pull/289)

## 5.15.6 (30 May 2018)

### Bug Fixes

* Ensure device data is attached to minimal reports [#279](https://github.com/bugsnag/bugsnag-cocoa/pull/279)
* Enforce requiring API key to initialise notifier [#280](https://github.com/bugsnag/bugsnag-cocoa/pull/280)

## 5.15.5 (25 Apr 2018)

### Bug Fixes

* Changes report generation so that when a minimal or incomplete crash is recorded, essential app/device information is included in the report on the next application launch. [#239](https://github.com/bugsnag/bugsnag-cocoa/pull/239)
[#250](https://github.com/bugsnag/bugsnag-cocoa/pull/250)

* Ensure timezone is serialised in report payload.
[#248](https://github.com/bugsnag/bugsnag-cocoa/pull/248)
[Jamie Lynch](https://github.com/fractalwrench)

## 5.15.4 (21 Feb 2018)

This release adds additional device metadata for filtering by whether an error
occurred in a simulator ([#242](https://github.com/bugsnag/bugsnag-cocoa/pull/242))
and by processor word size ([#228](https://github.com/bugsnag/bugsnag-cocoa/pull/228)).

### Bug Fixes

* Ensure error class and message are persisted when thread tracing is disabled
  [#245](https://github.com/bugsnag/bugsnag-cocoa/pull/245)
  [Jamie Lynch](https://github.com/fractalwrench)
* Re-addapp name to the app tab of reports
  [#244](https://github.com/bugsnag/bugsnag-cocoa/pull/244)
  [Jamie Lynch](https://github.com/fractalwrench)
* Add payload version to report body to preserve backwards compatibility with
  older versions of the error reporting API
  [#241](https://github.com/bugsnag/bugsnag-cocoa/pull/241)
  [Jamie Lynch](https://github.com/fractalwrench)

## 5.15.3 (23 Jan 2018)

### Bug Fixes

* Remove chatty logging from session tracking
  [#231](https://github.com/bugsnag/bugsnag-cocoa/pull/231)
  [Jamie Lynch](https://github.com/fractalwrench)
* Re-add API key to payload body to preserve backwards compatibility with older
  versions of the error reporting API
  [#232](https://github.com/bugsnag/bugsnag-cocoa/pull/232)
  [Jamie Lynch](https://github.com/fractalwrench)
* Fix crash in iPhone X Simulator when reporting user exceptions
  [#234](https://github.com/bugsnag/bugsnag-cocoa/pull/234)
  [Paul Zabelin](https://github.com/paulz)
* Improve capture of Swift assertion error messages on arm64 devices, inserting
  the assertion type into the report's `errorClass`
  [#235](https://github.com/bugsnag/bugsnag-cocoa/pull/235)

## 5.15.2 (11 Jan 2018)

### Bug Fixes

* Fix default user/device ID generation on iOS and tvOS devices
* Fix mach exception detection

## 5.15.1 (09 Jan 2018)

* Misc Session Tracking fixes and enhancements

## 5.15.0 (05 Jan 2018)

* - Adds support for tracking sessions and overall crash rate by setting `config.shouldAutoCaptureSessions` to `true`.
In addition, sessions can be indicated manually using `[Bugsnag startSession]` [#222](https://github.com/bugsnag/bugsnag-cocoa/pull/222)

## 5.14.2 (15 Dec 2017)

### Bug Fixes

* Fix possible crash when reading invalid JSON files from disk
  [#220](https://github.com/bugsnag/bugsnag-cocoa/pull/220)
  [#218](https://github.com/bugsnag/bugsnag-cocoa/issues/218)

## 5.14.1 (29 Nov 2017)

* Fix encoding of control characters in crash reports. Ensures crash reports are
  written correctly and delivered when containing U+0000 - U+001F
  [#214](https://github.com/bugsnag/bugsnag-cocoa/pull/214)
  [Jamie Lynch](https://github.com/fractalwrench)

## 5.14.0 (23 Nov 2017)

* Use `BSG_KSCrashReportWriter` header rather than `KSCrashReportWriter` for custom JSON serialization

## 5.13.5 (21 Nov 2017)

* Remove misleading information (address, mach, signal) from non-fatal error reports

## 5.13.4 (16 Nov 2017)

* Fix buffer overflow for reports with large metadata
* Treat warnings as errors

## 5.13.3 (06 Nov 2017)

* Fix build on older versions of XCode

## 5.13.2 (02 Nov 2017)

* Fix thread safety issue in breadcrumbs API
* Allow setting device ID in report to null
* When notifying of NSError, use the code and domain as the default context
* Fix for wrong report context in some unhandled errors

## 5.13.1 (26 Oct 2017)

* Additional method prefixing
* Prevent possible memory leak in connectivity check

## 5.13.0 (12 Oct 2017)

* Update podspec iOS version to 8.0
* Updated example apps to Swift 4
* Report error message for Swift's `fatalError`, `preconditionFailure`, `assertionFailure`, and `assert`.

## 5.12.1 (04 Oct 2017)

* Fix duplicate symbols in KSCrash when Sentry library included in project

## 5.12.0 (02 Oct 2017)

* Fix fatalError not producing crash report
* Update library's calculation of stack frame depth
* Reduced build warning count
* Track difference between handled and unhandled exceptions
  [#164](https://github.com/bugsnag/bugsnag-cocoa/pull/164)
  [Jamie Lynch](https://github.com/fractalwrench)

## 5.11.2 (15 Sep 2017)

* Fixed wrong tag in Cocoapods spec

## 5.11.1 (14 Sep 2017)

* Fixed issue with header file visibility

## 5.11.0 (14 Sep 2017)

* Update example apps to use Swift 3 syntax
* Discard duplicate automatic breadcrumbs recording orientation changes
* Map NSNotification keys in breadcrumbs into more human-readable strings
* Attempt to send reports stored on disk when connection regained
* Forked KSCrash library
* Improve performance in Bugsnag.notifyError [Eric Denman](https://github.com/edenman)

## 5.10.1 (08 Jun 2017)

### Bug fixes

* Fix warning generated by checking for existence of a property guaranteed when
  deployment target is iOS 8.0+
  [Scott Berrevoets](https://github.com/sberrevoets)
  [#147](https://github.com/bugsnag/bugsnag-cocoa/pull/147)

## 5.10.0 (22 May 2017)

### Enhancements

* Sanitize attached metadata to remove objects which cannot be serialized as
  JSON directly, logging during removal
* Make breadcrumb functionality available for background operations

### Bug fixes

* Lower effective deployment targets from iOS 8 and OS X 10.10 to iOS6 and OS X
  10.8

## 5.9.0 (08 May 2017)

### Enhancements

* Adds methods to `BugsnagCrashReport` for appending metadata, simplifying
  making the most common changes from a callback block
  [#145](https://github.com/bugsnag/bugsnag-cocoa/pull/145)

### Bug fixes

* Fix linking failure when using Bugsnag with Carthage on tvOS
  [#139](https://github.com/bugsnag/bugsnag-cocoa/issues/139)

## 5.8.0 (21 Apr 2017)

This release downgrades the dependent KSCrash version to 1.8.13, reverting the
change to the signature of `KSCrashReportWriter.addJSONElement()` in 5.7.0. This
change only affects users setting a custom `onCrash` handler to be executed at
crash time.

### Enhancements

* Increases the number of crash reports stored on disk before cycling
* Make logging configurable by setting `BSG_LOG_LEVEL`. Default is
  `BSG_LOGLEVEL_INFO`, and available values include `WARN` and `ERR` variants.

### Bug fixes

* Fixes deadlock which can occur when repeatedly calling `notify`
  [#143](https://github.com/bugsnag/bugsnag-cocoa/issues/143)
* Fixes periodic issue where no report is captured at all
* Fixes issue where a report written at crash time cannot be deserialized from
  disk at send time.

## 5.7.0 (30 Jan 2017)

This release updates the dependent KSCrash version to 1.11.2, which changes the
signature of `KSCrashReportWriter.addJSONElement()` to include whether to close
the JSON container.

### Enhancements

* Add support for customizing the `NSURLSession` used when sending error reports
  to Bugsnag
  [#127](https://github.com/bugsnag/bugsnag-cocoa/pull/127)

## 5.6.5 (7 Nov 2016)

### Bug fixes

* Fix assignment of `beforeSendBlocks` to incorrect property name
  [Spike Brehm](https://github.com/spikebrehm)
  [#125](https://github.com/bugsnag/bugsnag-cocoa/pull/125)

## 5.6.4 (7 Nov 2016)

### Miscellaneous

* Expose `app`, `appState`, `device`, `deviceState`, and `error` to crash report
  callback blocks

## 5.6.3 (21 Oct 2016)

### Bug fixes

* Fix `autoNotify`: Disabling unhandled exception capturing only sends
  user-reported exceptions via `Bugsnag.notify()`

## 5.6.2 (10 Oct 2016)

### Bug fixes

* Update imports to be compatible with KSCrash 1.8.8+
* Lock KSCrash dependency to 1.8.13 to reduce instability

## 5.6.1 (05 Oct 2016)

### Miscellaneous

* Include thread type in payload to match new payload specification

## 5.6.0 (26 Sep 2016)

### Enhancements

* Add support for attaching a custom stacktrace to an error report
* Upgrade required version of KSCrash

## 5.5.0 (14 Sep 2016)

### Enhancements

* Add "Require Only App-Extension-Safe API" flag for iOS App Extension support
* Send requests via NSURLSession by default

## 5.4.2 (17 Aug 2016)

### Bug fixes

* Fix a condition where bug reports would be sent multiple times


## 5.4.1 (27 Jul 2016)

### Bug fixes

* Fix breadcrumb type for table events
* Add error message and severity to error breadcrumbs
* Make breadcrumbs accessible from background queues

## 5.4.0 (22 Jul 2016)

### Enhancements

* Add support for automated breadcrumb collection for common events and the new
  breadcrumbs API
  [#112](https://github.com/bugsnag/bugsnag-cocoa/pull/112)

* Add support for Apple TV
  [#113](https://github.com/bugsnag/bugsnag-cocoa/pull/113)

* Add ability to customize error reports via `notify:block`
  [#110](https://github.com/bugsnag/bugsnag-cocoa/pull/110)

* Add support for sending reports for `NSError` instances via `notifyError:`
  and `notifyError:block:`
  [#110](https://github.com/bugsnag/bugsnag-cocoa/pull/110)

* Add crash time to the "Device" tab of error reports
  [#110](https://github.com/bugsnag/bugsnag-cocoa/pull/110)

## 5.3.0 (15 Jul 2016)

### Bug fixes

* Fix intermittent crashes via NSZombie detection being enabled by default
  [#111](https://github.com/bugsnag/bugsnag-cocoa/issues/111)
  [KSCrash#160](https://github.com/kstenerud/KSCrash/pull/160)

## 5.2.1 (16 June 2016)

Add Carthage support

## 5.2.0 (2 June 2016)

### Bug Fixes

* Catch JSON (de)serialization exceptions thrown from `NSJSONSerialization`

### Enhancements

* Add nullability annotations
* Remove logging when no reports were sent

## 5.1.0

### Bug Fixes

* Fix build failure when building with frameworks
  [#101](https://github.com/bugsnag/bugsnag-cocoa/issues/101)

### Enhancements

* Add support for iOS Application Extensions
  [#100](https://github.com/bugsnag/bugsnag-cocoa/issues/100)

## 5.0.2

### Bug Fixes

* Fix typo in updated payload date format. Should instead use RFC 3339 format

## 5.0.1

### Bug Fixes

* Fix header issue when linking to Bugsnag via CocoaPods from within another pod
  [#98](https://github.com/bugsnag/bugsnag-cocoa/issues/98)
  [#99](https://github.com/bugsnag/bugsnag-cocoa/pull/99)
  - Related to: [CocoaPods#4420](https://github.com/cocoapods/cocoapods/issues/4420)

## 5.0.0

This release includes an upgrade to [KSCrash](https://github.com/kstenerud/KSCrash)
1.0.0, as well support for running alongside other KSCrash-dependent libraries.
Crash handling for heap corruption and link register overwriting has also been
improved.

**NOTE:** The minimum supported iOS and OS X versions have been updated to 6.0
and 10.8 respectively.


### Bug Fixes

* Fix for occasional crash when logging from a failed network request
  [#67](https://github.com/bugsnag/bugsnag-cocoa/issues/67)

* Fix conflict when used alongside other KSCrash-dependent libraries
  [#41](https://github.com/bugsnag/bugsnag-cocoa/issues/41)
  [#52](https://github.com/bugsnag/bugsnag-cocoa/issues/52)
  [#72](https://github.com/bugsnag/bugsnag-cocoa/issues/72)
  [#91](https://github.com/bugsnag/bugsnag-cocoa/issues/91)
  [#94](https://github.com/bugsnag/bugsnag-cocoa/issues/94)

* Fix for failed crash reports being deleted instead of resent
  [#76](https://github.com/bugsnag/bugsnag-cocoa/issues/76)

### Enhancements

* Bitcode support
  [#78](https://github.com/bugsnag/bugsnag-cocoa/issues/78)

* Include breadcrumbs in uncaught exception reports
  [#78](https://github.com/bugsnag/bugsnag-cocoa/issues/93)
  [#86](https://github.com/bugsnag/bugsnag-cocoa/pull/86)

* Include severity in uncaught exception reports
  [#86](https://github.com/bugsnag/bugsnag-cocoa/pull/86)

* Add pre- and post-crash hooks, for modifying or rejecting crash reports
  [#17](https://github.com/bugsnag/bugsnag-cocoa/issues/17)
  [#47](https://github.com/bugsnag/bugsnag-cocoa/issues/47)
  [#34](https://github.com/bugsnag/bugsnag-cocoa/issues/34)
  [#88](https://github.com/bugsnag/bugsnag-cocoa/pull/88)

* Swift demangling support
  [#70](https://github.com/bugsnag/bugsnag-cocoa/issues/70)
  [#96](https://github.com/bugsnag/bugsnag-cocoa/pull/96)


4.1.0
-----

- Breadcrumbs support.
- Send notifications with current configuration rather than that in the report.

4.0.9
-----

- Protect against nil named exceptions

4.0.8
-----

- Reduce deployment target to 4.3
- Catch less crashes on OSX

4.0.7
-----

- Fix compilation on arm64 under Unity

4.0.6
-----

- Uncaught exceptions in OSX are now marked as warnings

4.0.5
-----

- Fix buffer over-read in JSON parser

4.0.4
-----

- Build OSX framework as part of release

4.0.3
-----

- In dealloc remove notifier from notifications

4.0.2
-----

- Make metaData access thread-safe

4.0.1
-----

- Fix warning while compiling KSCrash on OS X

4.0.0
-----

- Rewrite to use KSCrash as a solid foundation

3.1.3
-----
-   Add [Bugsnag notify:withMetaData:atSeverity:] to public API

3.1.2
-----
-   Prepare 'severity' feature for release

3.1.1
-----
-   Package BugsnagReachability in package for reliability

3.1.0
-----
-   Disable dsym uploading on iphonesimulator builds
-   Send better diagnostics with a better format

3.0.1
-----
-   Remove Pods from repo.
-   Fix XCode5 Warnings.
-   Publicise the notifier method.

3.0.0
-----
-   Complete rewrite to support symbolication.
-   Support iOS and OSX.
