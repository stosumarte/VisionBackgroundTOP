# VisionBackgroundTOP
Vision Background is a custom TouchDesigner TOP that leverages Apple's Vision framework to remove background from a video stream on macOS, similar to Nvidia Background on Windows.

This project is currently in alpha, and it needs still a lot of polishing and performance improvement work. Feel free to contribute!

## Requirements
* Apple Silicon
* macOS 13.5+
* TouchDesigner 2023+ (any license)

## Installing

### Option 1 — Global Installation (Recommended)

1. [Download the latest build from the releases tab](https://github.com/stosumarte/VisionBackgroundTOP/releases/latest) 

2. Unzip and copy `VisionBackgroundTOP.plugin` to TouchDesigner's plugin folder, which is located at `/Users/<username>/Library/Application Support/Derivative/TouchDesigner099/Plugins`. You might need to show hidden files by pressing `⌘⇧.`.

Now, you should be able to run TouchDesigner and find Vision Background under the "Custom" OPs panel.

⚠️ macOS may prevent the plugin from loading after download due to security quarantine flags. To fix this, open Terminal and type (without running):

`xattr -d -r com.apple.quarantine ~/Library/Application\ Support/Derivative/TouchDesigner099/Plugins/FreenectTD.plugin`

### Option 2 — Project-specific Installation

1. [Download the latest build from the releases tab](https://github.com/stosumarte/VisionBackgroundTOP/releases/latest) 

2. Unzip and copy `VisionBackgroundTOP.plugin` next to your .toe, in a folder named `Plugins`.

You should now be able to open your .toe and find Vision Background under the "Custom" OPs panel.

### Option 3 — CPlusPlus TOP

1. [Download the latest build from the releases tab](https://github.com/stosumarte/VisionBackgroundTOP/releases/latest) 

2. Unzip and copy `VisionBackgroundTOP.plugin` wherever you want on your machine.

3. Add a CPlusPlus TOP to your network, and select `VisionBackgroundTOP.plugin` under "Plugin Path" in the "Load" tab.

## Usage
Vision Background provides two parameters:
* Segmentation Quality: defaults to "Balanced", this currently provides roughly 50FPS on M3 Max.
* Downscale Factor: determines how much the image should be downscaled before Vision performs its magic. It seems to not impact performance for some reason, so you can leave it on 1x for the time being.

## Donations
If you like this plugin, please consider donating to support further development!
[You can donate here via PayPal.](https://www.paypal.com/donate/?hosted_button_id=PZXS4BCQJ9QMQ "You can donate here via PayPal.")
