# Contributing

Thanks for stopping by! This document should cover most topics surrounding contributing to `bugsnag-cocoa`.

* [How to contribute](#how-to-contribute)
  * [Reporting issues](#reporting-issues)
  * [Fixing issues](#fixing-issues)
  * [Adding features](#adding-features)
* [Building](#building)
* [Testing](#testing)
* [Releasing](#releasing)

## Reporting issues

Are you having trouble getting started? Please [contact us directly](mailto:support@bugsnag.com?subject=%5BGitHub%5D%20Cocoa%20-%20having%20trouble%20getting%20started%20with%20Bugsnag&body=Description%3A%0A%0A%28Add%20a%20description%20here%2C%20and%20fill%20in%20your%20environment%20below%3A%29%0A%0A%0AEnvironment%3A%0A%0A%0APaste%20the%20output%20of%20this%20command%20into%20the%20code%20block%20below%20%28use%20%60npm%20ls%60%20instead%0Aof%20%60yarn%20list%60%20if%20you%20are%20using%20npm%29%3A%0A%0A%60%60%60%0Ayarn%20list%20cocoa%20bugsnag-cocoa%20cocoa-code-push%0A%60%60%60%0A%0A-%20cocoapods%20version%20%28if%20any%29%20%28%60pod%20-v%60%29%3A%0A-%20iOS/Android%20version%28s%29%3A%0A-%20simulator/emulator%20or%20physical%20device%3F%3A%0A-%20debug%20mode%20or%20production%3F%3A%0A%0A-%20%5B%20%5D%20%28iOS%20only%29%20%60%5BBugsnagReactNative%20start%5D%60%20is%20present%20in%20the%0A%20%20%60application%3AdidFinishLaunchingWithOptions%3A%60%20method%20in%20your%20%60AppDelegate%60%0A%20%20class%3F%0A-%20%5B%20%5D%20%28Android%20only%29%20%60BugsnagReactNative.start%28this%29%60%20is%20present%20in%20the%0A%20%20%60onCreate%60%20method%20of%20your%20%60MainApplication%60%20class%3F) 
for assistance with integrating Bugsnag into your application.  If you have 
spotted a problem with this module, feel free to open a 
[new issue](https://github.com/bugsnag/bugsnag-cocoa/issues/new?template=Bug_report.md). 
Here are a few things to check before doing so:

* Are you using the latest version of `Bugsnag`? If not, does updating to the 
  latest version fix your issue?
* Has somebody else [already reported](https://github.com/bugsnag/bugsnag-cocoa/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen) 
  your issue? Feel free to add additional context to or check-in on an existing 
  issue that matches your own.
* Is your issue caused by this module? Only things related to the 
  `bugsnag-cocoa` module should be reported here. For anything else, please 
  [contact us directly](mailto:support@bugsnag.com) and we'd be happy to help 
  you out.

### Fixing issues

If you've identified a fix to a new or existing issue, we welcome contributions!
Here are some helpful suggestions on contributing that help us merge your PR 
quickly and smoothly:

* [Fork](https://help.github.com/articles/fork-a-repo) the
  [library on GitHub](https://github.com/bugsnag/bugsnag-cocoa)
* Build and test your changes. We have automated tests for many scenarios but 
  its also helpful to use `npm pack` to build the module locally and install it 
  in a real app.
* Commit and push until you are happy with your contribution
* [Make a pull request](https://help.github.com/articles/using-pull-requests)
* Ensure the automated checks pass (and if it fails, please try to address the 
  cause)

### Adding features

Unfortunately we’re unable to accept PRs that add features or refactor the 
library at this time.  However, we’re very eager and welcome to hearing 
feedback about the library so please contact us directly to discuss your idea, 
or open a [feature request](https://github.com/bugsnag/bugsnag-cocoa/issues/new?template=Feature_request.md) 
to help us improve the library.

Here’s a bit about our process designing and building the Bugsnag libraries:

* We have an internal roadmap to plan out the features we build, and sometimes 
  we will already be planning your suggested feature!
* Our open source libraries span many languages and frameworks so we strive to 
  ensure they are idiomatic on the given platform, but also consistent in 
  terminology between platforms. That way the core concepts are familiar whether 
  you adopt Bugsnag for one platform or many.
* Finally, one of our goals is to ensure our libraries work reliably, even in 
  crashy, multi-threaded environments. Oftentimes, this requires an intensive 
  engineering design and code review process that adheres to our style and 
  linting guidelines.

For an overview of source code organisation, see [ORGANIZATION.md](ORGANIZATION.md).

## Building

Each OS version of `Bugsnag` has an Xcode project in a directory named for the
OS. For example, to build and run `Bugsnag` for iOS, open
`iOS/Bugsnag.xcodeproj`.

## Testing

Run the unit tests for the `Bugsnag` library from Xcode or by running `make
test` on the command-line. To specify a specific iOS SDK, run with the SDK name:

    make SDK=iphonesimulator11.3 test

(The specified SDK must be installed in Xcode > Preferences > Components)
Or test on macOS:

    make PLATFORM=macOS test

Or to test on tvOS:

    make PLATFORM=tvOS test

Run the integration tests - see [TESTING.md](TESTING.md#end-to-end-tests).

## Releasing

### One time setup

1. Install release tools using `brew install cocoapods hub`
2. Sign in to CocoaPods trunk:

   ```
   pod trunk register notifiers@bugsnag.com 'Bugsnag Notifiers' --description='<your name>'
   ```

   (Remember to warn the platforms team to ignore the email)

3. Click the link in the email that got sent to the platforms team

### Pre-release steps

* Check the `master` and `next` branches for what changes are intended to be
  released. If any changes on `next` should go out, check out that branch before
  the subsequent steps.
* Add any missing entries to the CHANGELOG. Update the README if appropriate.
* Create a pull request for a new version by running `make VERSION=[number] 
  prerelease`. Pull request generation depends on [`hub`](https://hub.github.com) 
  (`brew install hub`)
* Perform preflight checks:
  - [ ] Have the CHANGELOG and README been updated?
  - [ ] Are there pull requests for installation changes on the 
        [dashboard](https://github.com/bugsnag/dashboard-js)?
  - [ ] Are there pull requests for new features/behavior on the 
        [docs site](https://github.com/bugsnag/docs.bugsnag.com)?
  - [ ] Run pre-release checks - see [instructions](./Tests/prerelease/README.md)
  
* Consider the following, additional checks based on changes in the release:
  
  - [ ] Has all new functionality been manually tested on a release build?
  - [ ] Do the [installation instructions](https://docs.bugsnag.com/platforms/ios/#installation) 
        work when creating an example app from scratch?  If using Cocoapods 
        remember to point at the pre-release branch in the `Podfile`, e.g.
        
    ```
    pod 'Bugsnag', :git => 'https://github.com/bugsnag/bugsnag-cocoa', :branch => '<prerelease-branch-name>'
    ```
        
  - [ ] Does the Carthage installation instruction work?
  - [ ] If a response is not received from the server, is the report queued for 
        later?
  - [ ] If no network connection is available, is the report queued for later?
  - [ ] On a throttled network, is the request timeout reasonable, and the main 
        thread not blocked?
  - [ ] Are queued reports sent asynchronously?
  - [ ] On a throttled network, is the request timeout reasonable, and the main 
        thread not blocked by any visible UI freeze? (Throttling can be achieved
        by setting both endpoints to "https://httpstat.us/200?sleep=5000")
  - [ ] Please ensure that release builds are run on a physical device with an 
        ad-hoc archive. (For release builds, select Edit Scheme, change the 
        Build Configuration to Release, and uncheck Debug Executable)

### Release steps

* Once the pull request is merged, publish the release by running `make release`
* A GitHub release page will open.  Fill in the release notes: `vMaj.Min.Patch`
  as a title and a summary of the changes from the CHANGELOG.  Look to previous
  releases for style guidance; _"This release fixes a number of issues..."_ etc.
* Click "Publish Release".
* Perform post-release checks:
  - [ ] Have all Docs and dashboard PRs been merged?
  - [ ] Do the installation instructions work using the released artefact?
  - [ ] Can a freshly created example app send an error report from a release 
        build, using the released artefact?
  - [ ] Do the existing example apps send an error report using the released 
        artefact?
* Plan to make releases to downstream libraries once adoption of the main
  library has begun, if appropriate (generally for bug fixes).  These include:
  * [bugsnag-js](https://github.com/bugsnag/bugsnag-js) - see [JS Contributing Guide](https://github.com/bugsnag/bugsnag-js/blob/next/packages/react-native/CONTRIBUTING.md#ios)
  * [bugsnag-cocos2dx](https://github.com/bugsnag/bugsnag-cocos2dx)
  * [bugsnag-unity](https://github.com/bugsnag/bugsnag-unity)

