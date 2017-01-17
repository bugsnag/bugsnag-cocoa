
We love people filing issues and sending pull requests!

How to contribute
-----------------

-   [Fork](https://help.github.com/articles/fork-a-repo) the [notifier on github](https://github.com/bugsnag/bugsnag-cocoa)
-   Commit and push until you are happy with your contribution
-   Test your changes
-   [Make a pull request](https://help.github.com/articles/using-pull-requests)
-   Thanks!

Running the tests
-----------------

Run the tests using the default SDK (iOS 9.2) by using:

    make test

Alternately, you can specify an iOS SDK:

    make SDK=iphonesimulator8.1 test

Or test on OS X:

    make BUILD_OSX=1 test

If you are interested in cleaner formatting, run `make bootstrap` to install
[xcpretty](https://github.com/supermarin/xcpretty) as an output formatter.


Releasing a new version
-----------------------

If you're a member of the core team, you can release the cocoa pod as follows:

### One time setup

* Install Cocoapods

    ```
    gem install cocoapods
    ```

* Register

    ```
    pod trunk register notifiers@bugsnag.com 'Bugsnag Notifiers' --description='your name'
    ```

* Click the link in the email that got sent to support

### Every time

* Update the CHANGELOG. Update the README.md if appropriate.
* Update the version number in `VERSION`, `Source/Bugsnag/BugsnagNotifier.m`,
  and `Bugsnag.podspec.json`
* Commit tag and push

    ```
    git commit -am v5.x.x
    git tag v5.x.x
    git push origin master v5.x.x
    ```

* Update cocoapods

    ```
    pod trunk push
    ```

* Create a new release https://github.com/bugsnag/bugsnag-cocoa/releases/new
* Select the tag you just pushed
* Set the title to the tag (v5.x.x)
* Copy the changelog entries into the release notes
* Click "Publish Release"
* Update the setup guides for Objective-C and Swift on docs.bugsnag.com with any
  new content
* Make releases to downstream libraries, if appropriate (generally for bug
  fixes)
