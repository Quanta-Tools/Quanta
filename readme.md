# Quanta.Tools Swift SDK

Welcome to the Quanta Swift SDK! This SDK allows you to easily integrate Quanta’s features into your iOS app, helping you leverage Quanta’s tools and analytics with just a few commands.

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

## Get Started Today!

Run the command and get ready to build with Quanta. For more information on our tools and features, check out [quanta.tools](https://quanta.tools).

Happy coding!
