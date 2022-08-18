# eduVPN iOS and macOS apps

These apps depend on [TunnelKit](https://github.com/keeshux/tunnelkit).

The app contains a [Network Tunneling Protocol Client](https://developer.apple.com/documentation/networkextension) and allows its users to create a VPN tunnel if you are able to connect to an eduVPN or Let's Connect enabled server.

## License

Copyright (c) 2020-2021 The Commons Conservancy. All rights reserved.

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

Dependencies are included as Swift Packages and managed through Xcode. We build against exact versions / commits of dependencies to keep it predictable.


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

### Pre-requisites

 1. SwiftLint and Go need to be installed. The build setup looks for these in the paths that HomeBrew installs into.

    To install, run:
    ~~~
    brew install swiftlint go
    ~~~

    Go version 1.16 is required.

 2. An explicit App ID needs to be created at the Apple Developer website for each platform

    To do this, you can:

     1. Go to your [Apple Developer account page](https://developer.apple.com/account/)
     2. Go to Certificates, IDs and Profiles > Identifiers
     3. Create an _App ID_ with an _Explicit_ _Bundle ID_, with the following _Capabilities_:
          - App Groups
          - Network Extensions
     4. Specify the _Bundle ID_ in the appropriate `Developer*.xcconfig` file as described below

### Building the eduVPN macOS app

To build the app, run:
```
$ cp Config/Mac/config-eduvpn_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/privacy_statement-eduvpn.json Config/Mac/privacy_statement.json
$ cp Config/Mac/Developer-macOS.xcconfig.eduvpn-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-macOS' target.

### Building the Let’s Connect! macOS app

To build the app, run:
```
$ cp Config/Mac/config-letsconnect_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/privacy_statement-letsconnect.json Config/Mac/privacy_statement.json
$ cp Config/Mac/Developer-macOS.xcconfig.letsconnect-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-macOS' target.

### Building the eduVPN iOS app

To build the app, run:
```
$ cp Config/iOS/config-eduvpn_new_discovery.json Config/iOS/config.json
$ cp Config/iOS/privacy_statement-eduvpn.json Config/iOS/privacy_statement.json
$ cp Config/iOS/Developer.xcconfig.eduvpn-template Config/iOS/Developer.xcconfig
$ vim Config/iOS/Developer.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-iOS' target.

### Building the Let’s Connect! iOS app

To build the app, run:
```
$ cp Config/iOS/config-letsconnect_new_discovery.json Config/iOS/config.json
$ cp Config/iOS/privacy_statement-letsconnect.json Config/iOS/privacy_statement.json
$ cp Config/iOS/Developer.xcconfig.letsconnect-template Config/iOS/Developer.xcconfig
$ vim Config/iOS/Developer.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-iOS' target.

## Testing

The app can be tested using UI tests written using XCUITest.

The tests can modify the app data, so to avoid losing your added
servers, it's recommended that you use a separate app bundle identifier
for running the UI tests. The app bundle identifier is configurable in
Developer.xcconfig or Developer-macOS.xcconfig as specified above.

### Testing the eduVPN iOS app

The iOS UI tests are intended to be run on a physical device (not on the
iOS Simulator).

Before running the tests, specify the server credentials:

```
$ cp EduVPN-UITests-iOS/TestServerCredentialsiOS.swift-template EduVPN-UITests-iOS/TestServerCredentialsiOS.swift
$ vim EduVPN-UITests-iOS/TestServerCredentialsiOS.swift # Enter credentials
```

Then:
 1. Open `EduVPN.xcworkspace` in Xcode
 2. Ensure the test targets (EduVPN-Tests-iOS, EduVPN-UITests-iOS) have
    correct 'Team' set under 'Signing & Capabilities'
 3. In the scheme selector breadcrumb panel, select the 'EduVPN-iOS'
    scheme and your connected iDevice
 4. Click on Product > Test

Do not use the iDevice when the test is running.

### Testing the eduVPN macOS app

Before running the tests, specify the server credentials:

```
$ cp EduVPN-UITests-macOS/TestServerCredentialsmacOS.swift-template EduVPN-UITests-macOS/TestServerCredentialsmacOS.swift
$ vim EduVPN-UITests-macOS/TestServerCredentialsmacOS.swift # Enter credentials
```

Then:
 1. Open Safari.app, open a new private window, close all other windows
 2. Open `EduVPN.xcworkspace` in Xcode
 3. Ensure the test targets (EduVPN-Tests-macOS, EduVPN-UITests-macOS) have
    correct 'Team' set under 'Signing & Capabilities'
 4. In the scheme selector breadcrumb panel, select the 'EduVPN-iOS'
    scheme and the macOS machine
 5. Click on Product > Test

Do not use the macOS machine when the test is running.
