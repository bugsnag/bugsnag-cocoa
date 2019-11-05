# Upgrading

Guide to ease migrations between significant changes

## v5 -> v6

Version 6 introduces a number of property and method renames:

### `BugsnagConfiguration` class

```diff
  let config = BugsnagConfiguration()

+ config.setMaxBreadcrumbs()

- config.autoNotify
+ config.autoDetectErrors
```

### `Bugsnag` class

```diff
- Bugsnag.setBreadcrumbCapacity(40)
  let config = BugsnagConfiguration()
+ config.setMaxBreadcrumbs(40)
```
