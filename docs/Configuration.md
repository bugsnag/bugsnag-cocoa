# Configuration for Bugsnag Cocoa

To configure additional Bugsnag settings, use the options available on the
`configuration` object listed below.

## Available Options

### `apiKey`

Your Bugsnag API key

```objective-c
[Bugsnag configuration].apiKey = @"YOUR-API-KEY";
```

### `appVersion`

If you want to manually track in which versions of your application each
exception happens, you can set `appVersion`.

```objective-c
[Bugsnag configuration].appVersion = @"5.3.55";
```

### `autoNotify`

By default, we will automatically notify Bugsnag of any fatal exceptions in your
application. If you want to stop this from happening, you can set `autoNotify`
to NO:

```objective-c
[Bugsnag configuration].autoNotify = NO;
```

### `beforeNotifyHooks`

When an app first launches after a crash or a manual notification is triggered,
crash reports are sent to Bugsnag. The `beforeNotifyHooks` allow you to
modify or filter report information uploaded. Each `report` has an `apiKey`,
`notifier` info, and `events`, which contains crash details and `metaData` about
the application state. The `rawEventReports` are the data written at crash-time,
including any additional information written during `onCrashHandler`.

**NOTE:** Segmentation faults and other similar crashes cannot be caught within
handlers.

```objective-c
BugsnagConfiguration *config = [BugsnagConfiguration new];
[config addBeforeNotifyHook:^NSDictionary *(NSArray *rawEventReports, NSDictionary *report) {
  NSMutableDictionary *reportCopy = [report mutableCopy];
  // ...
  return [reportCopy copy];
}];
```

### `context`

Bugsnag uses the concept of "contexts" to help display and group your errors.
Contexts represent what was happening in your application at the time an error
occurs. The Notifier will set this to be the top most UIViewController, but if
in a certain case you need to override the context, you can do so using this
property:

```objective-c
[Bugsnag configuration].context = @"MyUIViewController";
```

### `notifyReleaseStages`

By default, we notify Bugsnag of all exceptions that happen in your app. If you
would like to change which release stages notify Bugsnag of exceptions you can
set the `notifyReleaseStages` property:

```objective-c
[Bugsnag configuration].notifyReleaseStages = @[@"production"];
```

### `notifyURL`

By default Bugsnag sends reports to `https://notify.bugsnag.com/` if you need to
change this you can do so by starting Bugsnag with a different configuration
object.

```objective-c
BugsnagConfiguration *config = [[BugsnagConfiguration alloc] init];
config.notifyURL = [NSURL URLWithString:@"https://bugsnag.example.com/"];
config.apiKey = @"YOUR_API_KEY_HERE";
[Bugsnag startBugsnagWithConfiguration: config];
```

### `onCrashHandler`

When a crash occurs in an application, information about the runtime state of
the application is collected and prepared to be sent to Bugsnag on the next
launch. The `onCrashHandler` hook allows you to execute additional code after
the crash report has been written. This data is available for inspection after
the next launch during the [`beforeNotifyHooks`](#beforenotifyhooks) phase.

**NOTE:** All functions called from a signal handler must be
[asynchronous-safe](https://www.securecoding.cert.org/confluence/display/c/SIG30-C.+Call+only+asynchronous-safe+functions+within+signal+handlers).
This excludes any Objective-C, in particular.

```c
void HandleCrashedThread(const KSCrashReportWriter *writer) {
  // possibly serialize data, call another crash reporter
  writer->addJSONElement(writer, "dessertMap", dessertMapObj);
}

// ...

BugsnagConfiguration *config = [[BugsnagConfiguration alloc] init];
config.onCrashHandler = &HandleCrashedThread;
```

[Functions available on `KSCrashReportWriter`](https://github.com/kstenerud/KSCrash/blob/master/Source/KSCrash/Recording/KSCrashReportWriter.h)


### `releaseStage`

In order to distinguish between errors that occur in different stages of the
application release process a release stage is sent to Bugsnag when an error
occurs. This is automatically configured by the notifier to be "production",
unless DEBUG is defined during compilation. In this case it will be set to
"development". If you wish to override this, you can do so by setting the
releaseStage property manually:

```objective-c
[Bugsnag configuration].releaseStage = @"development";
```

### `user`

Bugsnag helps you understand how many of your users are affected by each error.
In order to do this, we send along a userId with every exception. By default we
will generate a unique ID and send this ID along with every exception from an
individual device.

If you would like to override this `userId`, for example to set it to be a
username of your currently logged in user, you can set the `userId` property:

```objective-c
[[Bugsnag configuration] setUser:@"userId" withName:@"User Name" andEmail:@"user@email.com"];
```

You can also set the email and name of the user and these will be searchable in
the dashboard.

