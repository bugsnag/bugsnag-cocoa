# Testing the Bugsnag Cocoa notifier

## Unit tests

Run the unit tests for the `Bugsnag` library from Xcode or by running `make
test` on the command-line. To specify a specific iOS SDK, run with the SDK name:

    make SDK=iphonesimulator11.3 test

Or test on macOS:

    make BUILD_OSX=1 test

Or to test on tvOS:

    make BUILD_TV=1 appletvsimulator11.2 test

## End-to-end tests

These tests are implemented with our notifier testing tool [Maze runner](https://github.com/bugsnag/maze-runner).

End to end tests are written in cucumber-style `.feature` files, and need Ruby-backed "steps" in order to know what to run. The tests are located in the ['features'](/features/) directory.

For testing against a real device, maze-runner's CLI and the test fixtures are containerised so you'll need Docker (and Docker Compose) to run them.

__Note: only Bugsnag employees can run the end-to-end tests.__ We have dedicated test infrastructure and private BrowserStack credentials which can't be shared outside of the organization.

#### Requirements

- Xcode
- Make
- Docker
- Docker-compose
- AWS `opensource` profile credentials
- BrowserStack credentials

#### Authenticating with the private container registry

You'll need to set the credentials for the aws profile in order to access the private docker registry:

```
aws configure --profile=opensource
```

Subsequently you'll need to run the following commmand to authenticate with the registry:

```
$(aws ecr get-login --profile=opensource --no-include-email)
```

__Your session will periodically expire__, so you'll need to run this command to re-authenticate when that happens.

#### Steps

Ensure the following environment variables are set:

- `BROWSER_STACK_USERNAME`: The BrowserStack App Automate Username
- `BROWSER_STACK_ACCESS_KEY`: The BrowserStack App Automate Access Key
- `DEVICE_TYPE` : The iOS version to run the tests against, one of: IOS_10, IOS_11, IOS_12, IOS_13

If you wish to test a single feature, set the `TEST_FEATURE` environment variable to the name of the feature file.  For example"
`export TEST_FEATURE=features/handled_errors.feature`

There are several `make` commands that will run various parts of the testing process:

- `make e2e` will build and run the test fixture against the remote device, repeating the build process every run.
- `make e2e_build` will build the test fixture, exporting it to the `features/fixtures/ios-swift-cocoapods/output/iOSTestApp.ipa` application file.
- `make e2e_run` will consume the built fixture and attempt to run either all the tests, or only those defined by `TEST_FEATURE`, against the remote device.
