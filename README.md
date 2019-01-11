# EduVPN iOS app

This app depends on [TunnelKit](https://github.com/keeshux/tunnelkit).

The app contains a [Network Tunneling Protocol Client](https://developer.apple.com/documentation/networkextension) and allows it's users to create a VPN tunnel if you are able to connect to an EduVPN or Let's Connect enabled server.

## Beware

Due to the usage of Network Extensions, you can not fully test this app on a Simulator.

> The infrastructure for Network Extension (NE) providers is simply not present on the simulator because, conceptually, it lives ‘below’ the kernel, and the simulator is layered on the OS X kernel.

[More info here.](https://forums.developer.apple.com/message/134358#134358)

## Provisioning

To allow this app to function you need three provisioning elements.

1. Provisioning profile for the app.
2. Provisioning profile for the network exension.
3. An App Group to which both of the above provisioning profiles have access.

## Building

- Clone repository
- Configure an XCConfig. Edit Developer.xcconfig.<eduvpn or letsconnect>-template in directory /ios/EduVPN/Config/. Edit app_name, development_team, app_ID, client_ID, REDIRECT_URL. In other file the discovery URL/key are configured, only needed for eduVPN app: Developer.xcconfig.template
- Open included xcworkspace with Xcode (type: xed .)
- Build
  
  ## Versioning
  Release tag from Github & build number set_build_number.sh (commits)
  

Dependencies are managed with CocoaPods. But this repository is set up in such a way that you do not need CocoaPods to build this project, only when updating dependencies.
Dependencies are defined in a [Podfile](https://github.com/eduvpn/ios/blob/master/Podfile), exact versions are 'locked' in [Podfile.lock](https://github.com/eduvpn/ios/blob/master/Podfile.lock). All dependencies defined in the Podfile are committed to this repository.

### Configuring
```
$ cp EduVPN/Config/Developer.xcconfig.template EduVPN/Config/Developer.xcconfig
```

Next edit `EduVPN/Config/Developer.xcconfig` with your favourite text editor and add values for all placeholders.

## Scripted build

Please see [build.sh](build.sh). (Work in progress.)

