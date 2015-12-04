# Notification Options for Bugsnag Cocoa

It is often useful to send additional meta-data about your app, such as
information about the currently logged in user, along with any
exceptions, to help debug problems.

## Severity

You can set the severity of an error in Bugsnag by including the severity option
when notifying bugsnag of the error:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil] withData:nil atSeverity:@"error"];
```

Valid severities are `error`, `warning` and `info`.

Severity is displayed in the dashboard and can be used to filter the error list.
By default all crashes (or unhandled exceptions) are set to `error` and all
`[Bugsnag notify]` calls default to `warning`.

## Adding Tabs to Bugsnag Error Reports

"Tabs" are additional groups of debugging information which can be added to
error reports.

If you want to add a tab to your Bugsnag error report, you can call the
`addToTab` method:

```objective-c
[Bugsnag addAttribute:@"username" withValue:@"bob-hoskins" toTabWithName:@"user"];
[Bugsnag addAttribute:@"registered-user" withValue:@"yes" toTabWithName:@"user"];
```

This will add a user tab to any error report sent to bugsnag.com that contains
the username and whether the user was registered or not.

You can clear a single attribute on a tab by calling:

```objective-c
[Bugsnag addAttribute:@"username" withValue:nil toTabWithName:@"user"];
```

or you can clear the entire tab:

```objective-c
[Bugsnag clearTabWithName:@"user"];
```

