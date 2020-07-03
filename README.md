# eduVPN iOS and macOS apps

These apps depend on [TunnelKit](https://github.com/keeshux/tunnelkit).

The app contains a [Network Tunneling Protocol Client](https://developer.apple.com/documentation/networkextension) and allows its users to create a VPN tunnel if you are able to connect to an eduVPN or Let's Connect enabled server.

## License

Copyright (c) 2020 The Commons Conservancy. All rights reserved.

### Part I

This project is licensed under the [GPLv3][license-content].

### Part II

As seen in [libsignal-protocol-c][license-signal]:

> Additional Permissions For Submission to Apple App Store: Provided that you are otherwise in compliance with the GPLv3 for each covered work you convey (including without limitation making the Corresponding Source available in compliance with Section 6 of the GPLv3), the Author also grants you the additional permission to convey through the Apple App Store non-source executable versions of the Program as incorporated into each applicable covered work as Executable Versions only under the Mozilla Public License version 2.0 (https://www.mozilla.org/en-US/MPL/2.0/).


## Beware

Due to the usage of Network Extensions, you can not fully test this app on a Simulator.

> The infrastructure for Network Extension (NE) providers is simply not present on the simulator because, conceptually, it lives ‘below’ the kernel, and the simulator is layered on the OS X kernel.

[More info here.](https://forums.developer.apple.com/message/134358#134358)

## Building

- Clone repository
- Configure an XCConfig. Check [Configuring](#Configuring) Section for more info.
- Open included xcworkspace with Xcode (In the terminal just type: `xed .`)
- Build
  

## Versioning

The build proces takes the number of commits on the current branch as the build number with `git rev-list HEAD --count`. The version string is configured in [AppVersion.xcconfig](EduVPN/Config/AppVersion.xcconfig).

The exact behavior is defined in the script [set_build_number.sh](Scripts/set_build_number.sh).

## Dependencies

Dependencies are managed with CocoaPods. But this repository is set up in such a way that you do not need CocoaPods to build this project, only when updating dependencies.
Dependencies are defined in a [Podfile](https://github.com/eduvpn/ios/blob/master/Podfile), exact versions are 'locked' in [Podfile.lock](https://github.com/eduvpn/ios/blob/master/Podfile.lock). All dependencies defined in the Podfile are committed to this repository.


## Configuring
Edit [config-template.json](EduVPN/Config/config-template.json) in directory.
Edit [Developer.xcconfig-template](EduVPN/Config/Developer.xcconfig-template) in directory.


Either copy the default template:
```
$ cp EduVPN/Config/config-template.json EduVPN/Config/config.json
$ cp EduVPN/Config/Developer.xcconfig-template EduVPN/Config/Developer.xcconfig
$ cp -r EduVPN/Config/Assets-EduVPN.xcassets EduVPN/Resources/Assets.xcassets
```

Or copy the letsconnect template:
```
$ cp EduVPN/Config/config-letsconnect.json EduVPN/Config/config.json
$ cp EduVPN/Config/Developer.xcconfig.letsconnect-template EduVPN/Config/Developer.xcconfig
$ cp -r EduVPN/Config/Assets-LetsConnect.xcassets EduVPN/Resources/Assets.xcassets
```

Or the EduVPN template:
```
$ cp EduVPN/Config/config-eduvpn.json EduVPN/Config/config.json
$ cp EduVPN/Config/Developer.xcconfig.eduvpn-template EduVPN/Config/Developer.xcconfig
$ cp -r EduVPN/Config/Assets-EduVPN.xcassets EduVPN/Resources/Assets.xcassets
```

Edit app_name, development_team, app_ID, client_ID, REDIRECT_URL.

**Be aware**
The app can be configured in thee distinct modes:

- Predefined, single provider.
- Discovery enabled.
- Only custom.

**Be aware**
When updating the Assets.xcassets, make sure to actually update the relevant .xcassets structures within EduVPN/Config

### Predefined

Add a `predefined_provider` key with a provier

### Discovery

Add a `discovery` key with content.

### Only custom

Do not add a `predefined_provider` or a `discovery` key.


## Scripted build

Please see [build.sh](build.sh). (Work in progress.)

