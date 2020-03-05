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
+ config.persistUser
+ [config persistUserData]
+ [config deletePersistedUserData]

+ config.setMaxBreadcrumbs()

- config.autoNotify
+ config.autoDetectErrors

- config.autoCaptureSessions
+ config.autoTrackSessions

- config.onCrashHandler
+ config.onError

- config.beforeSendBlocks
- config.add(beforeSend:)
+ config.onSendBlocks
+ config.add(onSend:)

- config.beforeSessionBlocks
- config.add(beforeSession:)
+ config.onSessionBlocks
+ config.add(onSession:)

- config.reportOOMs
+ config.enabledErrorTypes
```

### `Bugsnag` class

```diff
- Bugsnag.setBreadcrumbCapacity(40)
  let config = BugsnagConfiguration()
+ config.setMaxBreadcrumbs(40)
  let config = try BugsnagConfiguration("VALID 32 CHARACTER API KEY")

ObjC:

- [Bugsnag configuration]
+ [Bugsnag setUser:withName:andEmail:]

- [Bugsnag addAttribute:WithValuetoTabWithName:]
+ [Bugsnag addMetadataToSection:key:value:]

- [Bugsnag clearTabWithName:]
+ [Bugsnag clearMetadataInSection:]

+ [Bugsnag getSection:]

- [Bugsnag stopSession]
+ [Bugsnag pauseSession]

Swift:

- Bugsnag.configuration()
+ Bugsnag.setUser(_:name:email:)

- Bugsnag.addAttribute(attributeName:withValue:toTabWithName:)
+ Bugsnag.addMetadata(_:key:value:)

- Bugsnag.clearTab(name:)
+ Bugsnag.clearMetadata(_ section)

+ Bugsnag.getSection(_ section)

- Bugsnag.stopSession()
+ Bugsnag.pauseSession()
```

### `BugsnagMetadata` class

```diff

ObjC: 

- [BugsnagMetadata clearTabWithName:]
+ [BugsnagMetadata clearMetadataInSection:]

- [BugsnagMetadata getTab:]
+ [BugsnagMetadata getSection:]

+ [BugsnagMetadata addMetadataToSection:values:]

Swift:

- BugsnagMetadata.clearTab(name:)
+ BugsnagMetadata.clearMetadata(section:)

- BugsnagMetadata.getTab(name:)
+ BugsnagMetadata.getMetadata(_ section)
```

Note that `BugsnagMetadata.getTab()` previously would create a metadata section if it
did not exist; the new behaviour is to return `nil`. 

### `BugsnagBreadcrumb` class

The short "name" value has been removed and replaced with an arbitrarily long "message".

```diff
- BugsnagBreadcrumb.name
+ BugsnagBreadcrumb.message
```
