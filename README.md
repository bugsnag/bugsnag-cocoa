Bugsnag Notifier for Cocoa
==========================

The Bugsnag Notifier for Cocoa gives you instant notification of exceptions thrown from your *iOS* 4.3+ or *OSX* applications.
The notifier hooks into `NSSetUncaughtExceptionHandler`, which means any uncaught exceptions will trigger a notification to be sent to your Bugsnag dashboard. Bugsnag will also monitor for fatal signals sent to your application, for example, Segmentation Faults.

[Bugsnag](https://bugsnag.com) captures errors in real-time from your web, mobile and desktop applications, helping you to understand and resolve them as fast as possible. [Create a free account](https://bugsnag.com) to start capturing exceptions from your applications.


Installation & Setup
--------------------

###Using CocoaPods (Recommended)

[Cocoapods](http://cocoapods.org/) is a library management system for iOS/OSX which allows you to manage your libraries, detail your dependencies and handle updates nicely. It is the recommended way of installing the Bugsnag Cocoa library.

-   Add Bugsnag to your `Podfile`

    ```ruby
    pod 'Bugsnag', :git => "https://github.com/bugsnag/bugsnag-cocoa.git"
    ```

-   Install Bugsnag

    ```bash
    pod install
    ```

-   Import the `Bugsnag.h` file into your application delegate.

    ```objective-c
    #import "Bugsnag.h"
    ```

-   In your `application:didFinishLaunchingWithOptions:` method, initialize Bugsnag by calling,

    ```objective-c
    [Bugsnag startBugsnagWithApiKey:@"your-api-key-goes-here"];
    ```

-   In a Swift Project you might prefer to add Bugsnag as a framework in your Podfile.

    ```ruby
    use_frameworks!
    pod 'Bugsnag', :git => "https://github.com/bugsnag/bugsnag-cocoa.git"
    ```

-   Import the Bugsnag framework into your application delegate.

    ```swift
    import BugSnag
    ```

-   In your `application:didFinishLaunchingWithOptions:` method, initialize Bugsnag by calling,

    ```swift
    Bugsnag.startBugsnagWithApiKey("your-api-key-goes-here")
    ```

###Without Cocoapods

-   Download Bugsnag.zip from the [latest release](https://github.com/bugsnag/bugsnag-cocoa/releases/latest)

-   Drag Bugsnag.framework from the zip file into your project, enabling "Copy items if needed" when prompted.

-   Under "Build Settings" add "-ObjC" to "Other Linker Flags" (search for "ldflags")

-   Under "General" add "libc++" and "SystemConfiguration.framework" to "Linked Frameworks and Libraries"

-   Add a build phase to upload the symbolication information to Bugsnag

    From the same "Build Phases" screen, click the plus in the bottom right of the screen labelled "Add Build Phase", then select "Add Run Script". Then expand the newly added "Run Script" section, and set the shell to `/usr/bin/ruby` and copy the following script into the text box,

    ```ruby
    fork do
      Process.setsid
      STDIN.reopen("/dev/null")
      STDOUT.reopen("/dev/null", "a")
      STDERR.reopen("/dev/null", "a")

      require 'shellwords'

      Dir["#{ENV["DWARF_DSYM_FOLDER_PATH"]}/*/Contents/Resources/DWARF/*"].each do |dsym|
        system("curl -F dsym=@#{Shellwords.escape(dsym)} -F projectRoot=#{Shellwords.escape(ENV["PROJECT_DIR"])} https://upload.bugsnag.com/")
      end
    end
    ```

-   Import the `Bugsnag.h` file into your application delegate.

    ```objective-c
    #import <Bugsnag/Bugsnag.h>
    ```

-   In your `application:didFinishLaunchingWithOptions:` method, register with bugsnag by calling,

    ```objective-c
    [Bugsnag startBugsnagWithApiKey:@"your-api-key-goes-here"];
    ```

Mac Specific Setup
------------------

Mac exceptions in the main thread are caught by cocoa and don't reach Bugsnag by default. You should subclass NSApplication to get notifications sent to Bugsnag.

- Create a new Cocoa class in your Mac project that is a subclass of NSApplication.

- Import Bugsnag in the implementation

```objective-c
<Bugsnag/Bugsnag.h>
```

- Define a reportException method to notify Bugsnag of exceptions.

```objective-c
- (void)reportException:(NSException *)theException {
    [Bugsnag notify:theException];
    [super reportException:theException];
}
```

- Edit your target settings by clicking on the info tab and editing Principal class to contain your new NSApplication class name.

Exceptions on your main thread will now be sent to Bugsnag.

It is worth noting that you should also use `try{}catch{}` blocks inside your
application delegate functions and manually notify Bugsnag of any exceptions. This is another limitation of the exception handling
in Mac applications that the exception handler is only guaranteed to be called after application initialization has completed.

Send Non-Fatal Exceptions to Bugsnag
------------------------------------

If you would like to send non-fatal exceptions to Bugsnag, you can pass any `NSException` to the `notify` method:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]];
```

You can also send additional meta-data with your exception:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]
       withData:[NSDictionary dictionaryWithObjectsAndKeys:@"username", @"bob-hoskins", nil]];
```

### Severity

You can set the severity of an error in Bugsnag by including the severity option when
notifying bugsnag of the error,

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil] withData:nil atSeverity:@"error"];
```

Valid severities are `error`, `warning` and `info`.

Severity is displayed in the dashboard and can be used to filter the error list.
By default all crashes (or unhandled exceptions) are set to `error` and all
`[Bugsnag notify]` calls default to `warning`.

Adding Tabs to Bugsnag Error Reports
------------------------------------

If you want to add a tab to your Bugsnag error report, you can call the `addToTab` method:

```objective-c
[Bugsnag addAttribute:@"username" withValue:@"bob-hoskins" toTabWithName:@"user"];
[Bugsnag addAttribute:@"registered-user" withValue:@"yes" toTabWithName:@"user"];
```

This will add a user tab to any error report sent to bugsnag.com that contains the username and whether the user was registered or not.

You can clear a single attribute on a tab by calling:

```objective-c
[Bugsnag addAttribute:@"username" withValue:nil toTabWithName:@"user"];
```

or you can clear the entire tab:

```objective-c
[Bugsnag clearTabWithName:@"user"];
```

Configuration
-------------

###context

Bugsnag uses the concept of "contexts" to help display and group your errors. Contexts represent what was happening in your application at the time an error occurs. The Notifier will set this to be the top most UIViewController, but if in a certain case you need to override the context, you can do so using this property:

```objective-c
[Bugsnag configuration].context = @"MyUIViewController";
```

###user

Bugsnag helps you understand how many of your users are affected by each error. In order to do this, we send along a userId with every exception. By default we will generate a unique ID and send this ID along with every exception from an individual device.

If you would like to override this `userId`, for example to set it to be a username of your currently logged in user, you can set the `userId` property:

```objective-c
[[Bugsnag configuration] setUser:@"userId" withName:@"User Name" andEmail:@"user@email.com"];
```

You can also set the email and name of the user and these will be searchable in the dashboard.

###releaseStage

In order to distinguish between errors that occur in different stages of the application release process a release stage is sent to Bugsnag when an error occurs. This is automatically configured by the notifier to be "production", unless DEBUG is defined during compilation. In this case it will be set to "development". If you wish to override this, you can do so by setting the releaseStage property manually:

```objective-c
[Bugsnag configuration].releaseStage = @"development";
```

###notifyReleaseStages

By default, we notify Bugsnag of all exceptions that happen in your app. If you would like to change which release stages notify Bugsnag of exceptions you can set the `notifyReleaseStages` property:

```objective-c
[Bugsnag configuration].notifyReleaseStages = [NSArray arrayWithObjects:@"production", nil];
```

###autoNotify

By default, we will automatically notify Bugsnag of any fatal exceptions in your application. If you want to stop this from happening, you can set `autoNotify` to NO:

```objective-c
[Bugsnag configuration].autoNotify = NO;
```

###notifyURL

By default Bugsnag sends reports to `https://notify.bugsnag.com/` if you need to change this you can do so by starting Bugsnag with a different configuration object.

```objective-c
BugsnagConfiguration *config = [[BugsnagConfiguration alloc] init];
config.notifyURL = [NSURL URLWithString:@"https://bugsnag.example.com/"];
config.apiKey = @"YOUR_API_KEY_HERE";
[Bugsnag startBugsnagWithConfiguration: config];
```

Reporting Bugs or Feature Requests
----------------------------------

Please report any bugs or feature requests on the github issues page for this project here:

<https://github.com/bugsnag/bugsnag-cocoa/issues>


Contributing
------------

We love getting issue reports, and pull requests. For more detailed instructions see [CONTRIBUTING.md](https://github.com/bugsnag/bugsnag-cocoa/blob/master/CONTRIBUTING.md)

License
-------

The Bugsnag Cocoa notifier is free software released under the MIT License. See [LICENSE.txt](https://github.com/bugsnag/bugsnag-cocoa/blob/master/LICENSE.txt) for details.
