<div align="center">
  <a href="https://www.bugsnag.com/platforms/ios">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://assets.smartbear.com/m/3dab7e6cf880aa2b/original/BugSnag-Repository-Header-Dark.svg">
      <img alt="SmartBear BugSnag logo" src="https://assets.smartbear.com/m/3945e02cdc983893/original/BugSnag-Repository-Header-Light.svg">
    </picture>
  </a>
  <h1>Error monitoring &amp; exception reporter for iOS, macOS, tvOS and watchOS</h1>
</div>

[![Documentation](https://img.shields.io/badge/documentation-latest-blue.svg)](https://docs.bugsnag.com/platforms/ios/)
[![Build status](https://badge.buildkite.com/bc15523ca2dc56d1a9fd61a1c0e93b99adba62f229a1c3379b.svg?branch=master)](https://buildkite.com/bugsnag/bugsnag-cocoa)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/bugsnag/bugsnag-cocoa/badge)](https://scorecard.dev/viewer/?uri=github.com/bugsnag/bugsnag-cocoa)

Detect crashes in your iOS, macOS, tvOS and watchOS applications: collecting diagnostic information and immediately notifying your development team, helping you to understand and resolve issues as fast as possible.

## Features

* Automatically report unhandled exceptions and crashes
* Report handled exceptions
* Log breadcrumbs which are attached to crash reports and add insight to users' actions
* Attach user information and custom diagnostic data to determine how many people are affected by a crash

## Getting started

### iOS

1. [Create a Bugsnag account](https://bugsnag.com)
1. Complete the instructions in the integration guide for [iOS](https://docs.bugsnag.com/platforms/ios/)
1. Report handled exceptions using [`[Bugsnag notify:]`](https://docs.bugsnag.com/platforms/ios/reporting-handled-exceptions/)
1. Customize your integration using the [configuration options](https://docs.bugsnag.com/platforms/ios/configuration-options/)

### macOS

1. [Create a Bugsnag account](https://bugsnag.com)
1. Complete the instructions in the integration guide for [macOS](https://docs.bugsnag.com/platforms/macos/)
1. Report handled exceptions using [`[Bugsnag notify:]`](https://docs.bugsnag.com/platforms/macos/reporting-handled-exceptions/)
1. Customize your integration using the [configuration options](https://docs.bugsnag.com/platforms/macos/configuration-options/)

### watchOS

1. [Create a Bugsnag account](https://bugsnag.com)
1. Complete the instructions in the integration guide for [watchOS](https://docs.bugsnag.com/platforms/watchos/)
1. Report handled exceptions using [`[Bugsnag notify:]`](https://docs.bugsnag.com/platforms/watchos/reporting-handled-exceptions/)
1. Customize your integration using the [configuration options](https://docs.bugsnag.com/platforms/watchos/configuration-options/)

## Support

* Read the [iOS](https://docs.bugsnag.com/platforms/ios/configuration-options), [macOS](https://docs.bugsnag.com/platforms/macos/configuration-options), [tvOS](https://docs.bugsnag.com/platforms/tvos/configuration-options) or [watchOS](https://docs.bugsnag.com/platforms/watchos/configuration-options) configuration reference
* [Search open and closed issues](https://github.com/bugsnag/bugsnag-cocoa/issues?utf8=✓&q=is%3Aissue) for similar problems
* [Report a bug or request a feature](https://github.com/bugsnag/bugsnag-cocoa/issues/new)

## Contributing

All contributors are welcome! For information on how to build, test and release `bugsnag-cocoa`, see our [contributing guide](https://github.com/bugsnag/bugsnag-cocoa/blob/master/CONTRIBUTING.md).

## License

The BugSnag Cocoa SDK is free software released under the MIT License. See the [LICENSE](https://github.com/bugsnag/bugsnag-cocoa/blob/master/LICENSE) for details.
