Creating a Bugsnag Plugin
=========================

Making a plugin that plays nice with the major package managers can be tricky. Here's how to do it safely:


Creating the Plugin
-------------------

#### Add a new target for your plugin:

- Open `Bugsnag.xcworkspace`
- Select the `Bugsnag` project
- In the `Targets` pane, click `+`
- Use the `Framework` template (ios)
- Give it a name like `BugsnagXYZ`
- Select the `BugsnagXYZ` target
- Under `General` -> `Frameworks and Libraries`, click `+` and add the `Bugsnag.framework` for your architecture (ios)

#### Apply fixups and workarounds:

In the targets pane (`Bugsnag` project in the left pane, `Targets` list in the middle pane):
- Rename the `BugsnagXYZ` target to `BugsnagXYZ-iOS`
- Rename the `BugsnagXYZTests` target to `BugsnagXYZ-iOSTests`

In the target's build settings (`Bugsnag` project in the left pane, `Targets` list in the middle pane, `BugsnagXYZ-iOS`, `Build Settings`):
- Change `Product Name` from `BugsnagXYZ-iOS` to `BugsnagXYZ`

In the schemes manager (Click the schemes selector in the middle pane -> `Manage Schemes`):
- Rename the `BugsnagXYZ `scheme to `BugsnagXYZ-iOS`
- Untick and re-tick the new scheme's `Shared` checkbox (this generates the needed .xcscheme file)
- Click `+` and add the `BugsnagXYZ-iOSTests` target.

#### You should now have:

- New targets: `BugsnagXYZ-iOS` and `BugsnagXYZ-iOSTests`
- New schemes: `BugsnagXYZ-iOS` and `BugsnagXYZ-iOSTests`
- New top-level directories: `BugsnagXYZ` and `BugsnagXYZTests`

#### Add your code:

- Place all new code inside the `BugsnagXYZ` directory.
- Make sure your new files have appropriate `BugsnagXYZ-nnn` membership in the right-side pane.
- Create the directory `BugsnagXYZ/include/Bugsnag` and place all public headers in there.
- Make sure all public headers are marked as public in the right-side pane (they're `Project` by default).
- When importing from the main Bugsnag library, use angle bracket style (`#import <Bugsnag/whatever.h>`)

#### Add other platform targets:

You must also make targets and schemes for the other platforms (macOS, tvOS) pointing to the same `BugsnagXYZ` codebase, similar to what's done in the main Bugsnag library. Do so by creating a new `BugsnagXYZ` target for each platform, then renaming to e.g. `BugsnagXYZ-macOS` like you did for iOS, then updating existing source files to include membership in the new target.


Supporting Carthage
-------------------

Carthage looks in your project for shared schemas, so everything should already be set up, and users should be able to reference the new plugin once you've pushed.

### Using in a local testing app

Use a `file://` reference in your tester app's Cartfile:

```
git "file:///path/to/bugsnag-cocoa" "my-exploratory-branch"
```

Then update Carthage: `carthage update --use-xcframeworks`

Now add `Bugsnag.framework` and `BugsnagXYZ.framework` from `Carthage/Build/` to your project.

**Note**: Carthage will only see changes that have been committed to your bugsnag-cocoa git repo!


Supporting Swift Package Manager
--------------------------------

Modify `Package.swift`.

Add a new entry to `products`:

```
        .library(name: "BugsnagXYZ", targets: ["BugsnagXYZ"]),
```

Add a new entry to `targets`:

```
        .target(
            name: "BugsnagXYZ",
            dependencies: ["Bugsnag"],
            path: "BugsnagXYZ",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("include/Bugsnag"),
            ]
        ),
```

Once your changes are pushed, users can reference the new plugin.

### Using in a local testing app

1. Drag the `bugsnag-cocoa` folder (containing `Package.swift`) into the Navigator tab (left side) of your tester app project in xcode.
2. In your app project's general settings, go to `Frameworks, Libraries, and Embedded Content`, click `+` and add the appropriate `Bugsnag` and `BugsnagXYZ` products.


Supporting Cocoapods
--------------------

Create a `BugsnagXYZ.podspec` file similar to the existing `Bugsnag.podspec` file:

```
Pod::Spec.new do |s|
  s.name             = 'BugsnagXYZ'
  s.version          = '6.11.0'
  s.summary          = 'Bugsnag XYZ plugin.'

  s.description      = <<-DESC
A plugin that does XYZ.
                       DESC

  s.homepage         = 'https://bugsnag.com'
  s.license          = 'MIT'
  s.authors          = { 'Bugsnag': 'notifiers@bugsnag.com' }

  s.source           = {
    :git => 'https://github.com/bugsnag/bugsnag-cocoa.git',
    :tag => 'v' + s.version.to_s
  }

  s.ios.deployment_target = '9.3'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.2'

  s.cocoapods_version = '>= 1.4.0'

  s.dependency 'Bugsnag', '~> ' + s.version.to_s

  s.source_files = "BugsnagXYZ/{**/,}*.{m,h,mm,c}"
  s.requires_arc = true
  s.prefix_header_file = false
  s.public_header_files = "BugsnagXYZ/include/Bugsnag/*.h"
end
```

**Note**: The plugin podspec version must remain lockstep with the main `Bugsnag.podspec` version.

### Using in a local testing app

Make sure your testing app's `Podfile` has the following entries:

```
  pod 'Bugsnag', :path => "/path/to/bugsnag-cocoa"
  pod 'BugsnagXYZ', :path => "/path/to/bugsnag-cocoa"
```

Then run `pod install` and open the generated .xcworkspace file
