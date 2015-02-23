
We love people filing issues and sending pull requests!

How to contribute
-----------------

-   [Fork](https://help.github.com/articles/fork-a-repo) the [notifier on github](https://github.com/bugsnag/bugsnag-cocoa)
-   Commit and push until you are happy with your contribution
-   [Make a pull request](https://help.github.com/articles/using-pull-requests)
-   Thanks!

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
* Update the version number in `Source/Bugsnag/BugsnagNotifier.m` and `Bugsnag.podspec`
* Commit tag and push

    ```
    git commit -am v4.x.x
    git tag v4.x.x
    git push origin master v4.x.x
    ```

* Update cocoapods

    ```
    pod trunk push
    ```

* Build a new Zipfile to build/relase/Bugsnag-4.x.x.zip

    ```
    rake build
    ```

* Create a new release https://github.com/bugsnag/bugsnag-cocoa/releases/new
* Select the tag you just pushed
* Set the title to the tag (v4.x.x)
* Copy the changelog entries into the release notes
* Drag and drop the zipfile
* Click "Publish Release"

