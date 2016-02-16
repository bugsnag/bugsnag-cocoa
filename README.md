Bugsnag Notifier for Cocoa <a href="https://travis-ci.org/bugsnag/bugsnag-cocoa"><img src="https://travis-ci.org/bugsnag/bugsnag-cocoa.svg?branch=master" alt="build status" class="build-status"></a>
==========================

The Bugsnag Notifier for Cocoa gives you instant notification of exceptions
thrown from your **iOS** 6.0+ or **OS X** 10.8+ applications. The notifier hooks
into `NSSetUncaughtExceptionHandler`, which means any uncaught exceptions will
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
  - [Crash Report Symbolication](#crash-report-symbolication)
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

[CocoaPods](http://cocoapods.org/) is a library management system for iOS/OSX
which allows you to manage your libraries, detail your dependencies and handle
updates nicely. It is the recommended way of installing the Bugsnag Cocoa
library.

0.  Install CocoaPods

    ```
    gem install cocoapods
    ```

1.  Add Bugsnag to your `Podfile`

    ```ruby
    pod 'Bugsnag'

    ```

    In a Swift Project you might prefer to add Bugsnag as a framework in your
    Podfile

    ```ruby
    use_frameworks!
    pod 'Bugsnag'
    ```

2.  Install Bugsnag

    ```bash
    pod install
    ```

#### Without CocoaPods

1.  Download Bugsnag.zip from the [latest release](https://github.com/bugsnag/bugsnag-cocoa/releases/latest)

2.  Drag Bugsnag.framework from the zip file into your project, enabling "Copy
    items if needed" when prompted.

3.  Add Bugsnag.framework to the "Embedded Binaries" section of the "General"
    tab of project settings

4.  Add [KSCrash.framework](https://github.com/kstenerud/KSCrash#how-to-use-kscrash)
    to your project and the required dependencies. Bugsnag requires KSCrash
    v1.0.0 or greater.

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

### Crash Report Symbolication

The Bugsnag Cocoa Notifier supports symbolicating crash reports from client
devices. In order to make this work, Bugsnag needs the contents of your dSYM
file.

#### With Bitcode

If you have [Bitcode](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/AppThinning/AppThinning.html#//apple_ref/doc/uid/TP40012582-CH35-SW2)
enabled in your application's project settings:

1. Open the Xcode Organizer, select your app, then use "Download dSYMs..." to
   download the dSYM files.
2. Upload the dSYM file to Bugsnag using the [dSYM Upload API](https://bugsnag.com/docs/notifiers/ios/dsym):

       curl https://upload.bugsnag.com/ -F dsym=@MyApp.app.dSYM/Contents/Resources/DWARF/MyApp

#### Without Bitcode

Without Bitcode enabled, the dSYM files for your application can be
automatically uploaded by adding a build phase to your project. If you are using
CocoaPods, installing the [cocoapods-bugsnag plugin](https://github.com/bugsnag/cocoapods-bugsnag)
will add the build phase when you run `pod install`. Otherwise:

1. From the same "Build Phases" screen, click the plus in the bottom right of
   the screen labelled "Add Build Phase", then select "Add Run Script"
2. Expand the newly added "Run Script" section, and set the shell to
   `/usr/bin/ruby`
3. Copy the following script into the text box:

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

