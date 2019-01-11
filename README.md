# EduVPN iOS app

This app depends on [TunnelKit](https://github.com/keeshux/tunnelkit).

The app contains a [Network Tunneling Protocol Client](https://developer.apple.com/documentation/networkextension) and allows it's users to create a VPN tunnel if you are able to connect to an EduVPN or Let's Connect enabled server.

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

The build proces takes the number of commits on the current branch as the build number with `git rev-list HEAD --count`. The version string is taken from the repository with `git describe --tags --always --abbrev=0`.

The exact behavior is defined in the script [set_build_number.sh](Scripts/set_build_number.sh).

If you want to create a new version of the app, make sure to create a tag of the format `vX.Y.Z`. For example: `v2.0.1` or `v3.5.1`.
  

## Dependencies

Dependencies are managed with CocoaPods. But this repository is set up in such a way that you do not need CocoaPods to build this project, only when updating dependencies.
Dependencies are defined in a [Podfile](https://github.com/eduvpn/ios/blob/master/Podfile), exact versions are 'locked' in [Podfile.lock](https://github.com/eduvpn/ios/blob/master/Podfile.lock). All dependencies defined in the Podfile are committed to this repository.


## Configuring
Edit [config-template.json](EduVPN/Config/config-template.json) in directory.

Either copy the default template:
```
$ cp EduVPN/Config/config.json EduVPN/Config/config.json
```

Or copy the letsconnect template:
```
$ cp EduVPN/Config/config-letsconnect.json EduVPN/Config/config.json
```

Or the EduVPN template:
```
$ cp EduVPN/Config/config-eduvpn.json EduVPN/Config/config.json
```

Edit app_name, development_team, app_ID, client_ID, REDIRECT_URL. In other file the discovery URL/key are configured, only needed for eduVPN app: Developer.xcconfig.template


## Scripted build

Please see [build.sh](build.sh). (Work in progress.)

