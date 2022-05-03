Creating a Bugsnag Plugin
=========================

Making a plugin that plays nice with the major package managers can be tricky. Here's how to do it safely:


Creating the Plugin
-------------------

**Note**: Xcode project files are very fragile and buggy, and tend to break when you make changes to them. Usually you'll end up with phantom targets, or crashes after which the project file won't load anymore. You may have to quit Xcode, wipe out all changes and start over a few times:

```
git restore --staged .
git checkout .
git clean -df
```

Once your project is properly set up, quit Xcode and then reopen the workspace to make sure the project file is okay.

#### Add a new project for your plugin

- Open `Bugsnag.xcworkspace`
- From the menu, select `File` -> `New` -> `Project`
- Use the `Framework` template (ios)
- Give it a name like `BugsnagXYZ`
- Make sure it is part of workspace `Bugsnag`
- Select the `BugsnagXYZ` target
- Under `General` -> `Frameworks and Libraries`, click `+` and add the `Bugsnag.framework` for your architecture (ios). Set its `Embed` type to `Do not embed`.
- Under `General` -> `Deployment Info`, make sure `Deployment Target` matches the targets in the main `Bugsnag` project (you may need to manually edit the `.pbxproj` file in a text editor to change the various `xyz_DEPLOYMENT_TARGET` fields).

#### Apply fixups and workarounds:

In the targets pane (`BugsnagXYZ` project in the left pane, `Targets` list in the middle pane):
- Rename the `BugsnagXYZ` target to `BugsnagXYZ-iOS`
- Rename the `BugsnagXYZTests` target to `BugsnagXYZ-iOSTests`

In the target's build settings (`Bugsnag` project in the left pane, `Targets` list in the middle pane, `BugsnagXYZ-iOS`, `Build Settings`):
- Change `Product Name` from `BugsnagXYZ-iOS` to `BugsnagXYZ`

In the schemes manager (Click the schemes selector in the middle pane -> `Manage Schemes`):
- Rename the `BugsnagXYZ `scheme to `BugsnagXYZ-iOS`
- Untick and re-tick the new scheme's `Shared` checkbox (this generates the needed .xcscheme file)
- Edit the scheme and make sure under the `Tests` section it has the target `BugsnagXYZ-iOSTests` (use `+` to add it if it's missing)
- Use the `+` button to add the `BugsnagXYZ-iOSTests` scheme (Cocoapods generates a broken project if there's no test scheme)

#### You should now have:

- New targets: `BugsnagXYZ-iOS` and `BugsnagXYZ-iOSTests`
- New schemes: `BugsnagXYZ-iOS` and `BugsnagXYZ-iOSTests`
- New top-level directories: `BugsnagXYZ` and `BugsnagXYZTests`

#### Add other targets:

You must add support for the following platforms: `macOS`, `tvOS`. Your additional targets will share the same base directories `BugsnagXYZ` and `BugsnagXYZTests`.

- Select the `BugsnagXYZ` project, then in the center pane in the `Targets` list, click `+`
- Select a platform (macOS, tvOS, etc) and choose the `Framework` template
- Call it `BugsnagXYZ` like you did for the main target
- Delete the extra `BugsnagXYZ` and `BugsnagXYZTests` groups that were added to the `BugsnatXYZ` project (remove references only).
- Apply fixups and workarounds like you did for the iOS target

#### Add your code:

- Place all new code inside the `BugsnagXYZ` directory.
- Make sure your new files have appropriate `BugsnagXYZ-nnn` membership in the right-side pane.
- Create the directory `BugsnagXYZ/BugsnagXYZ/include/BugsnagXYZ` and place all public headers in there.
- Add the `include` directory as a group in your project.
- Make sure all public headers are marked as public in the right-side pane (they're `Project` by default).
- When importing from the main Bugsnag library, use angle bracket style (`#import <Bugsnag/whatever.h>`)


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

Add a new entry to `targets` (note `BugsnagXYZ/BugsnagXYZ` because of how Xcode structures the project):

```
        .target(
            name: "BugsnagXYZ",
            dependencies: ["Bugsnag"],
            path: "BugsnagXYZ/BugsnagXYZ",
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

Create a `BugsnagXYZ.podspec.json` file similar to the existing `Bugsnag.podspec.json` file:

```
{
  "name": "BugsnagXYZ",
  "version": "6.11.0",
  "summary": "A Bugsnag plugin that does XYZ.",
  "homepage": "https://bugsnag.com",
  "license": "MIT",
  "authors": {
    "Bugsnag": "notifiers@bugsnag.com"
  },
  "source": {
    "git": "https://github.com/bugsnag/bugsnag-cocoa.git",
    "tag": "v6.11.0"
  },
  "dependencies": {
    "Bugsnag": "6.11.0"
  },
  "platforms": {
    "ios": "9.0",
    "osx": "10.11",
    "tvos": "9.2"
  },
  "source_files": [
    "BugsnagXYZ/BugsnagXYZ/{**/,}*.{m,h,mm,c}"
  ],
  "requires_arc": true,
  "prefix_header_file": false,
  "public_header_files": [
    "BugsnagXYZ/BugsnagXYZ/include/Bugsnag/*.h"
  ]
}
```

**Notes**:
- The plugin podspec version must remain lockstep with the main `Bugsnag.podspec.json` version.
- The source files will have the directory structure `BugsnagXYZ/BugsnagXYZ` because of how Xcode structures the project.

### Using in a local testing app

Make sure your testing app's `Podfile` has the following entries:

```
  pod 'Bugsnag', :path => "/path/to/bugsnag-cocoa"
  pod 'BugsnagXYZ', :path => "/path/to/bugsnag-cocoa"
```

Then run `pod install` and open the generated .xcworkspace file
