![](https://img.shields.io/github/v/release/quanta-tools/quanta)

# Quanta.Tools Swift SDK

Welcome to the Quanta Swift SDK! This SDK allows you to easily integrate Quanta’s features into your iOS app, helping you leverage Quanta’s tools and analytics with just a few commands.

## Xcode Error: `Missing package product 'Quanta'`

In Xcode, run

1. File → Packages → Reset Package Caches
1. **Restart Xcode**
1. File → Packages → Resolve Package Versions

The issue should be gone.

## Sending Events

The most important thing to know about the Quanta SDK is how to send events. You can use the `log` method like this:

```swift
Quanta.log(event: "purchase")
Quanta.log(event: "purchase", revenue: 1.99)
Quanta.log(event: "purchase", addedArguments: "monthly")
Quanta.log(event: "purchase", revenue: 1.99, addedArguments: ["period": "monthly"])
```

## Screen Tracking

Track user screen views with the `.track()` modifier on your SwiftUI views:

```swift
SomeView().track(screen: "my screen name")
```

This automatically captures:

- Screen name
- Optional arguments you can provide
- View time in seconds (duration user spends on screen)

## Quick Start

To get started, simply run the following command in your terminal. This script will automatically set up Quanta in your Xcode project:

```bash
/bin/bash -c "$(curl -L ios.quanta.tools)"
```

For more details on Quanta and its tools, visit our [landing page](https://quanta.tools).

## What Does the Installation Script Do?

Nothing, unless you select any of the following steps. When you run the script, it asks you exactly what you want it to do, and every single step is optional.

To streamline the setup, we provide the following options in the quanta setup script:

1. **Check Dependencies**: The script checks if `brew`, `jq`, and `plutil` are installed. If they’re missing, the script installs them for you.

2. **Add Quanta as an SPM Dependency**: The script adds the Quanta SDK’s Git repository as a Swift Package Manager (SPM) dependency, integrating it directly into your Xcode project.

3. **Generate a New App ID**: The script generates a unique AppId for your project and saves it to a `Quanta.plist` file. This ID is used to uniquely identify your app in Quanta’s system.

4. **Configure Xcode Targets**: The script automatically adds the `Quanta.plist` file to every target in your Xcode project, ensuring all targets have access to the Quanta AppId.

5. **Add `import Quanta` to Entry Points**: For convenience, `import Quanta` is added to the main entry point file of every Xcode target, so you can start using Quanta’s features right away.

**All Of These Steps Are Optional. Run The Script And Select Which Steps You Want To Enable.**

## Why Use This Script?

The installation script is designed to save time and ensure that the SDK is configured correctly in your project. With just a single command, it takes care of dependency management, app identification, and project configuration.

By automating these steps, we eliminate setup errors and allow you to focus on building with Quanta from the start.

You can always add this git repository manually with Swift Package Manager. Please ensure that you create a Quanta.plist file with an AppId field present and add it to every target of your Xcode project that you intend to submit analytics events from.

## Manual Installation: SPM

You can always just add this repo manually by adding https://github.com/Quanta-Tools/Quanta.git as a new package to your [Xcode project](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

Adding `import Quanta` to your app's entrypoint(s) will start sending anonymous user data and launch events. The only added setup step is setting a Quanta AppId in your project. The SDK will warn you if it's not correctly set up.

### Quanta.plist

You can add an AppId by creating a new property list file and adding an `AppId` key with a new UUID. To create a random UUID, run the command `uuidgen` in your macOS terminal. Make sure to add this new property list to all your [Xcode targets](/add-plist.md).

Additionally, the following configuration options are available:

- `noLaunchEvent` (Boolean): When set to `true`, prevents sending the automatic `launch` event when your app starts.
- `noInitOrLaunchEvent` (Boolean): When set to `true`, prevents sending the `launch` event and skips the automatic initialization that normally happens 3 seconds after launch.

### Quanta.appId

Alternatively, you can leverage the 3 second init delay of Quanta to set an appId programmatically before Quanta loads. You can set `Quanta.appId` before the Quanta loaded message shows up in your logs. A content view `onAppear` or an app delegate's `applicationDidFinishLaunching` works well for this.

## Get Started Today!

Run the command and get ready to build with Quanta. For more information on our tools and features, check out [quanta.tools](https://quanta.tools).

Happy coding!
