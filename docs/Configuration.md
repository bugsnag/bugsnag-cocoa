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

