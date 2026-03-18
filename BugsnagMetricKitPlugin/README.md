# BugsnagMetricKitPlugin

Automatic MetricKit integration for Bugsnag.

This plugin automatically captures and reports diagnostic information from Apple's MetricKit framework as Bugsnag error events. MetricKit provides system-level crash diagnostics, CPU exceptions, app hangs, disk write exceptions, and app launch failures.

## Installation

### CocoaPods

Add the plugin to your `Podfile`:

```ruby
pod 'BugsnagMetricKitPlugin', '~> 6.13'
```

Then run `pod install`.

### Swift Package Manager

Add the plugin as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/bugsnag/bugsnag-cocoa.git", from: "6.13.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["Bugsnag", "BugsnagMetricKitPlugin"]
    )
]
```

### Manual

1. Add `BugsnagMetricKitPlugin.framework` to your project's "Link Binary With Libraries" build phase
2. Add `MetricKit.framework` as an optional (weak) framework

## Usage

The plugin automatically loads when linked to your app - no additional configuration needed!

```swift
// 1. Configure and start Bugsnag as normal
let config = BugsnagConfiguration("YOUR-API-KEY")
Bugsnag.start(with: config)

// 2. That's it! The MetricKit plugin automatically initializes if linked.
```

### Configuration

You can control which MetricKit diagnostic types are reported via the Bugsnag configuration:

```swift
let config = BugsnagConfiguration("YOUR-API-KEY")

// Enable or disable specific diagnostic types
config.enabledMetricKitDiagnostics.enabled = true
config.enabledMetricKitDiagnostics.crashDiagnostics = true
config.enabledMetricKitDiagnostics.cpuExceptionDiagnostics = true
config.enabledMetricKitDiagnostics.hangDiagnostics = true
config.enabledMetricKitDiagnostics.diskWriteExceptionDiagnostics = true
config.enabledMetricKitDiagnostics.appLaunchDiagnostics = true // iOS 16+ only

Bugsnag.start(with: config)
```

## Supported Platforms

- iOS 13.0+
- macOS 12.0+
- visionOS 1.0+

Note: MetricKit is not available on tvOS or watchOS.

## Diagnostic Types

The plugin reports the following MetricKit diagnostic types:

### Crash Diagnostics
System-recorded app crashes including exception type, termination reason, and call stack.
- Error classes: `EXC_BAD_ACCESS`, `EXC_BAD_INSTRUCTION`, etc.

### CPU Exception Diagnostics
Terminations due to excessive CPU usage or CPU-related exceptions.
- Error class: `CPUException`

### Hang Diagnostics
App hangs where the app becomes unresponsive.
- Error class: `App Hang`

### Disk Write Exception Diagnostics
Errors related to disk write operations.
- Error class: `DiskWriteException`

### App Launch Diagnostics (iOS 16+)
Failures that occur during app launch.
- Error class: `AppLaunchFailure`

## Event Metadata

All MetricKit events include:
- **source**: Set to `"metrickit"` to distinguish from regular crashes
- **diagnosticPayload**: Full JSON representation of the MetricKit diagnostic

## How It Works

1. The plugin registers with Apple's MetricKit framework when Bugsnag starts
2. MetricKit delivers diagnostic payloads (typically on the next app launch after an issue)
3. The plugin converts each diagnostic into a Bugsnag error event
4. Events are uploaded using Bugsnag's existing delivery infrastructure

## Differences from Regular Crash Reporting

MetricKit diagnostics:
- Are delivered by the system (usually on next launch)
- May not include all contextual data (breadcrumbs, metadata) 
- Provide Apple's official crash classification
- Have a 10-25% opt-in rate among users
- Complement Bugsnag's existing crash reporting

## License

The BugsnagMetricKitPlugin is MIT licensed. See [LICENSE.txt](../LICENSE.txt) for details.
