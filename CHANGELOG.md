Changelog
=========

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
