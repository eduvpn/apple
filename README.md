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

## Versioning

The build proces takes the number of commits on the current branch as the build number with `git rev-list HEAD --count`. The version string is configured in [AppVersion.xcconfig](EduVPN/Config/AppVersion.xcconfig).

The exact behavior is defined in the script [set_build_number.sh](Scripts/set_build_number.sh).

## Dependencies

Dependencies are managed with CocoaPods. But this repository is set up in such a way that you do not need CocoaPods to build this project, only when updating dependencies.
Dependencies are defined in a [Podfile](https://github.com/eduvpn/ios/blob/master/Podfile), exact versions are 'locked' in [Podfile.lock](https://github.com/eduvpn/ios/blob/master/Podfile.lock). All dependencies defined in the Podfile are committed to this repository.

## Building

There are two flavours of apps that are built from the same codebase:

  - [eduVPN](https://www.eduvpn.org) app
  - [Let’s Connect!](https://www.letsconnect-vpn.org) app

This needs to be configured in two files, which are different for macOS
and iOS:

  - For macOS:
      - `Config/Mac/config.json`
      - `Config/Mac/Developer-macOS.xcconfig`
  - For iOS:
      - `Config/iOS/config.json`
      - `Config/iOS/Developer.xcconfig`

### Building the eduVPN macOS app

To build the app, run:
```
$ cp Config/Mac/config-eduvpn_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/Developer-macOS.xcconfig.eduvpn-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```
and build the 'EduVPN-macOS' target in Xcode.

### Building the Let’s Connect! macOS app

To build the app, run:
```
$ cp Config/Mac/config-letsconnect_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/Developer-macOS.xcconfig.letsconnect-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```
and build the 'EduVPN-macOS' target in Xcode.

### Building the eduVPN iOS app

To build the app, run:
```
$ cp Config/iOS/config-eduvpn_new_discovery.json Config/iOS/config.json
$ cp Config/iOS/Developer.xcconfig.eduvpn-template Config/iOS/Developer.xcconfig
$ vim Config/iOS/Developer.xcconfig # Edit as reqd.
```
and build the 'EduVPN-iOS' target in Xcode.

### Building the Let’s Connect! iOS app

To build the app, run:
```
$ cp Config/iOS/config-letsconnect_new_discovery.json Config/iOS/config.json
$ cp Config/iOS/Developer.xcconfig.letsconnect-template Config/iOS/Developer.xcconfig
$ vim Config/iOS/Developer.xcconfig # Edit as reqd.
```
and build the 'EduVPN-iOS' target in Xcode.

