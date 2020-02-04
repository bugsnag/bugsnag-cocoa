# Upgrading

Guide to ease migrations between significant changes

## v5 -> v6

Version 6 introduces a number of property and method renames:

### BugsnagCrashReport class

This is now BugsnagEvent.

### `BugsnagConfiguration` class

```diff
  let config = BugsnagConfiguration("YOUR API KEY HERE")

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
```
