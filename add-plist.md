# How to add Quanta.plist to your Xcode target

Adding a non-code file, like a .plist file, to all targets in Xcode is straightforward! Here’s how you can make sure it’s included in every target (including widget extensions, watch apps, etc.) within your project:

## Step-by-Step Guide

### Locate the File in Xcode:

First, make sure your .plist file is already in your Xcode project.
If it’s not there yet, you can drag the file from Finder into the Xcode project navigator. Drop it in the folder where you want it to live (often within the main project folder).

### Open the File Inspector:

Select the .plist file in your project navigator (left sidebar).
On the right side of Xcode, open the File Inspector tab (usually the first tab in the Inspector panel on the right).

### Add to All Targets:

In the File Inspector, scroll to the section labeled Target Membership.
You’ll see a list of checkboxes for each target in your project (such as the main app, any extensions, and widgets).
Check all the boxes for the targets that need this .plist file. This ensures the file is included in the build bundle of each target, so it’ll be accessible at runtime.

### Verify File Placement in the Bundle (Optional):

When you build your app, Xcode will automatically bundle this file into each target's app bundle if you’ve selected them in the Target Membership section.
To check, you can look in the Products folder in the Xcode navigator after a build and ensure that the .plist file appears under each target as expected.
And that's it! Now your .plist file is part of every target in your Xcode project. Each target, including widget extensions and others, will have access to it.
