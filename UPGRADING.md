# Upgrading

Guide to ease migrations between significant changes

## v5 -> v6

Version 6 introduces a number of property and method renames:

### BugsnagCrashReport class

This is now BugsnagEvent.

### `BugsnagConfiguration` class

```diff
ObjC: 

  NSError *error;
  BugsnagConfiguration *config = [[BugsnagConfiguration alloc] initWithApiKey:"YOUR API KEY HERE" error:error];

Swift:

  let config = try BugsnagConfiguration("YOUR API KEY HERE")

+ BSGConfigurationErrorDomain
+ BSGConfigurationErrorCode

+ config.setMaxBreadcrumbs()

- config.autoNotify
+ config.autoDetectErrors

- config.autoCaptureSessions
+ config.autoTrackSessions
```

### `Bugsnag` class

```diff
- Bugsnag.setBreadcrumbCapacity(40)
  let config = BugsnagConfiguration()
+ config.setMaxBreadcrumbs(40)
  let config = try BugsnagConfiguration("VALID 32 CHARACTER API KEY")

ObjC:

- [Bugsnag addAttribute:WithValuetoTabWithName:]
+ [Bugsnag addMetadataToSection:key:value:]

Swift:

- Bugsnag.addAttribute(attributeName:withValue:toTabWithName:)
+ Bugsnag.addMetadata(_:key:value:)
```
