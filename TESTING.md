# Testing the Bugsnag Cocoa notifier

## Unit tests

Run the unit tests for the `Bugsnag` library from Xcode or by running `make
test` on the command-line. To specify a specific iOS SDK, run with the SDK name:

    make SDK=iphonesimulator11.3 test

Or test on macOS:

    make PLATFORM=macOS test

Or to test on tvOS:

    make PLATFORM=tvOS test

## End-to-end tests

These tests are implemented with our notifier testing tool [Maze runner](https://github.com/bugsnag/maze-runner).

End to end tests are written in cucumber-style `.feature` files, and need Ruby-backed "steps" in order to know what to 
run. The tests are located in the ['features'](/features/) directory.

For testing against a real device, maze-runner's CLI and the test fixtures are containerized so you'll need Docker 
(and Docker Compose) to run them.

__Note: only Bugsnag employees can run the end-to-end tests.__ We have dedicated test infrastructure and private 
BrowserStack credentials that cannot be shared outside of the organization.

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

1. Ensure the following environment variables are set:
    - `MAZE_DEVICE_FARM_USERNAME` - your BrowserStack App Automate Username
    - `MAZE_DEVICE_FARM_ACCESS_KEY` - your BrowserStack App Automate Access Key
    - `MAZE_BS_LOCAL` - location of the `BrowserStackLocal` executable on your local file system
1. Build the test fixtures:
    ```shell script
    make test-fixtures
    ```
1. Check the contents of `Gemfile` to select the version of `maze-runner` to use
1. See https://www.browserstack.com/local-testing/app-automate for details of the required local testing binary.
1. To run a single feature:
    ```shell script
    bundle exec maze-runner --app=features/fixtures/ios/output/iOSTestApp.ipa \
                            --farm=bs                                         \
                            --device=IOS_14                                   \
                            features/app_and_device_attributes.feature
    ```
1. To run all features, omit the final argument.
1. Maze Runner supports various other option, as well as all those that Cucumber does. For full details run:
    ```shell script
    `bundle exec maze-runner --help`
    ```
