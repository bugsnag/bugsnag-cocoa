Changelog
=========


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
