Bugsnag Notifier for Cocoa <img src="https://travis-ci.org/bugsnag/bugsnag-cocoa.svg?branch=master" alt="build status" class="build-status">
==========================

The Bugsnag Notifier for Cocoa gives you instant notification of exceptions
thrown from your **iOS** 5.0+ or **OSX** applications. The notifier hooks into
`NSSetUncaughtExceptionHandler`, which means any uncaught exceptions will
trigger a notification to be sent to your Bugsnag dashboard. Bugsnag will also
monitor for fatal signals sent to your application such as Segmentation
Faults.

[Bugsnag](https://bugsnag.com) captures errors in real-time from your web,
mobile and desktop applications, helping you to understand and resolve them as
fast as possible. [Create a free account](https://bugsnag.com) to start
capturing exceptions from your applications.

Contents
--------

- [Getting Started](#getting-started)
	- [Installation](#installation)
	- [Setup](#setup)
		- [Objective-C](#objective-c)
		- [Swift](#swift)
		- [Additional Setup for Mac Applications](#additional-setup-for-mac-applications)
- [Usage](#usage)
	- [Catching and Reporting Exceptions](#catching-and-reporting-exceptions)
	- [Sending Handled Exceptions](#sending-handled-exceptions)
	- [Logging Breadcrumbs](#logging-breadcrumbs)
- [Demo Applications](#demo-applications)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

- [Additional Documentation](docs/)
	- [Configuration](docs/Configuration.md)
	- [Notification Options](docs/Notification Options.md)



Getting Started
---------------

### Installation

#### Using CocoaPods (Recommended)

[Cocoapods](http://cocoapods.org/) is a library management system for iOS/OSX
which allows you to manage your libraries, detail your dependencies and handle
updates nicely. It is the recommended way of installing the Bugsnag Cocoa
library.

0.  Install Cocoapods and the [Bugsnag Cocoapods Plugin](https://github.com/bugsnag/cocoapods-bugsnag).
    The plugin is not required, but it adds a build phase to your projects for
    uploading dSYM files to Bugsnag for symbolicating crash reports.

    ```
    gem install cocoapods cocoapods-bugsnag
    ```

1.  Add Bugsnag to your `Podfile`

    ```ruby
    pod 'Bugsnag', :git => "https://github.com/bugsnag/bugsnag-cocoa.git"

    ```

    In a Swift Project you might prefer to add Bugsnag as a framework in your
    Podfile

    ```ruby
    use_frameworks!
    pod 'Bugsnag', :git => "https://github.com/bugsnag/bugsnag-cocoa.git"
    ```

2.  Install Bugsnag

    ```bash
    pod install
    ```

#### Without Cocoapods

1.  Download Bugsnag.zip from the [latest release](https://github.com/bugsnag/bugsnag-cocoa/releases/latest)

2.  Drag Bugsnag.framework from the zip file into your project, enabling "Copy
    items if needed" when prompted.

3.  Under "Build Settings" add "-ObjC" to "Other Linker Flags" (search for
    "ldflags")

4.  Under "General" add "libc++" and "SystemConfiguration.framework" to "Linked
    Frameworks and Libraries"

5.  Add a build phase to upload the symbolication information to Bugsnag

    From the same "Build Phases" screen, click the plus in the bottom right of
    the screen labelled "Add Build Phase", then select "Add Run Script". Then
    expand the newly added "Run Script" section, and set the shell to
    `/usr/bin/ruby` and copy the following script into the text box,

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


### Setup

After installation, the Bugsnag library must be imported into your project and
initialized with your API key.

#### Objective-C

1.  Import the `Bugsnag.h` file into your application delegate.

    ```objective-c
    #import <Bugsnag/Bugsnag.h>
    ```

2.  In your `application:didFinishLaunchingWithOptions:` method, initialize
    Bugsnag by calling,

    ```objective-c
    [Bugsnag startBugsnagWithApiKey:@"your-api-key-goes-here"];
    ```

#### Swift

1.  Import the Bugsnag framework into your application delegate.

    ```swift
    import Bugsnag
    ```

2.  In your `application:didFinishLaunchingWithOptions:` method, initialize
    Bugsnag by calling,

    ```swift
    Bugsnag.startBugsnagWithApiKey("your-api-key-goes-here")
    ```


#### Additional Setup for Mac Applications

Mac exceptions in the main thread are caught by cocoa and don't reach Bugsnag by
default. You should subclass NSApplication to get notifications sent to Bugsnag.

- Create a new Cocoa class in your Mac project that is a subclass of
  NSApplication.

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

- Edit your target settings by clicking on the info tab and editing Principal
  class to contain your new NSApplication class name.

Exceptions on your main thread will now be sent to Bugsnag.

It is worth noting that you should also use `try{}catch{}` blocks inside your
application delegate functions and manually notify Bugsnag of any exceptions.
This is another limitation of the exception handling in Mac applications that
the exception handler is only guaranteed to be called after application
initialization has completed.

Usage
-----

### Catching and Reporting Exceptions

Once the setup is complete, Bugsnag automatically reports unhandled exceptions
in your projects. There are additional options available for sending handled
exceptions to Bugsnag.

### Sending Handled Exceptions

If you would like to send non-fatal exceptions to Bugsnag, you can pass any
`NSException` to the `notify` method:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]];
```

You can also send additional meta-data with your exception:

```objective-c
[Bugsnag notify:[NSException exceptionWithName:@"ExceptionName" reason:@"Something bad happened" userInfo:nil]
       withData:@{@"username": @"bob-hoskins"}];
```

### Logging Breadcrumbs

You can add custom log messages called "breadcrumbs" to document what user
interactions occurred in your application prior to a crash. Each breadcrumb also
records the time at which it was left. To record a breadcrumb:

```objective-c
[Bugsnag leaveBreadcrumbWithMessage:@"Button tapped"];
```

Demo Applications
-----------------

The repository includes a few example applications for various configurations:

- [iOS (Objective-C)](https://github.com/bugsnag/bugsnag-cocoa/tree/master/examples/objective-c-ios)
- [iOS (Swift)](https://github.com/bugsnag/bugsnag-cocoa/tree/master/examples/swift-ios)
- [OS X (Objective-C)](https://github.com/bugsnag/bugsnag-cocoa/tree/master/examples/objective-c-osx)


Support
-------

* [Additional Documentation](https://github.com/bugsnag/bugsnag-cocoa/tree/master/docs)
* [Search open and closed issues](https://github.com/bugsnag/bugsnag-cocoa/issues?utf8=✓&q=is%3Aissue) for similar problems
* [Report a bug or request a feature](https://github.com/bugsnag/bugsnag-cocoa/issues/new)


Contributing
------------

We'd love you to file issues and send pull requests. The
[contributing guidelines](CONTRIBUTING.md) details the process of building and
testing `bugsnag-cocoa`, as well as the pull request process. Feel free to
comment on [existing issues](https://github.com/bugsnag/bugsnag-cocoa/issues)
for clarification or starting points.


License
-------

The Bugsnag Cocoa notifier is free software released under the MIT License.
See [LICENSE.txt](LICENSE.txt) for details.

