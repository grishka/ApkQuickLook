# QuickLook plugin for APKs

![Screenshot](/screenshot.jpg)

#### Features
* QuickLook panel for APKs that shows the app name, icon, package ID, version, permissions, target and minimum SDKs, and (optionally) signature certificate info & validity
    * Signatures are disabled by default because they take around one second to verify. To enable them, run `defaults write me.grishka.ApkQuickLook checkSignatures -bool yes` in Terminal.
* APKs display their app icons as file icons in Finder

#### Installation
I recommend downloading an installer package from Releases and using that, but if you prefer doing things manually, here's how it's done:
1. Copy ApkQuickLook.qlgenerator to either ~/Library/QuickLook/ to install it just for yourself or to /Library/QuickLook/ to install it for all users. You'll need the root password in the latter case.
2. Run `qlmanage -r` to load the plugin into the QuickLook daemon.