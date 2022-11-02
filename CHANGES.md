# Changelog

## Unreleased

- Bring back ENOBUFS fix
- Avoid crypto errors (103) while sending packets #481

## 3.0.3

- Move project to use Swift Package Manager instead of Cocoapods #95
- Revert ENOBUFS fix

## 3.0.2

- Make connected time consistent with transferred data count #319
- Fix ASWebAuthenticationSession failure when clicking
  on a session expiry notification #469
- When deleting a single secure internet server, app
  should automatically show the search screen

## 3.0.1

- Fix when 'Renew Session' button is shown #460
- Ensure app works on the iPad
- Ensure Settings and Help buttons are visible on the iPad

## 3.0.0

- Support for minisign pre-hashed signatures #427
- Add server API events to the log #424
- Show 'Renew Session' whenever it's possible to renew #430
- Update TunnelKit
  - Use TunnelKit as Swift Package Manager package
  - Avoid writing client certificate and private key to disk
  - Not upstreamed: Handle ENOBUFS errors
- Notify on session expiry #442
- Avoid staggered alerts related to session expiry #445
- Show privacy statement on launch #454
- Allow access to privacy statement from Settings / Preferences
- Update list of available secure internet servers on startup #447
- APIv3: Use prefer_tcp, fix accept header for '/connect'
- Support for net_gateway / net_gateway_ipv6 in OpenVPN #440

## 2.2.4

- macOS: Support keyboard navigation #331
- Make fetching of info.json cancellable #415
- Handle wrong scheme when pasting a custom server URL #407
- Make "Connect using TCP only" work with APIv3
- Suppress 'Renew Session' for 30 mins after authentication time #417
- macOS: Ability to reset the app #259
- macOS: Show alert on wakeup if session expiry notification was missed #400

## 2.2.3

- Support for APIv3 and WireGuard
- Bugfix: VPN switch is no longer disabled after connecting after first launch
- Show renew button if we have <1 week to expiry
- Use "/.well-known/vpn-user-portal" instead of "/info.json"
- macOS: Status item icons changed
- iOS: Support for password-based OpenVPN configs
- macOS: Can press return to connect when prompted for password
- Rollback prevention for discovery data
- macOS: Improve HTML page shown after OAuth authentication completes #182
- Updated dependencies

## 2.2.2

- Notify before session expiry
- macOS: Let's Connect: Update status item image

## 2.2.1

- macOS: App requires macOS 10.15 or later
- Importing OpenVPN configs #125
- macOS: Support for password-based OpenVPN configs
- macOS: Native support for Apple Silicon macs
- macOS: Toggle VPN from system menu
- iOS: Fix 'Change Location' to make first location choosable #375
- Use strings in discovery data correctly based on system language #374
- Auto-focus the search field when applicable #330
- Let's Connect: Remove discovery-related features #294
- Let's Connect: Support for pre-defined provider

## 2.2.0 (2020-11-12)

- iOS: Display Let's Connect! app with proper (full) display name. #301
- Notify certificate expiry with a local notification #90

## 2.1.9 Let's Connect! / eduVPN

- macOS: GUI redesign
- macOS: New discovery mechanism

## 2.1.7 Let's Connect! (2020-05-22) / eduVPN

- iOS/Mac: Updated dependencies: TunnelKit & AlamoFire.
- iOS/Mac: Added german translation
- iOS/Mac: Preserve tunnel log across the previous tunnel invocation
- iOS/Mac: Fix for connection getting stuck in Connecting state #248
- iOS/Mac: Add back notification indicating certificate expiration. #235
- iOS: On removing the "home" instance, all instances authentating through this home insance will alse be removed. Cascade deletion of Api accross `authorizingForGroup` relation. #241
- macOS/iOS: Remove certificate experiation notification.
- iOS: Fix for #216: "when 'connecting' there is no 'disconnect' button"
- macOS: Support for "on demand" added (always on) #220
- iOS: "On demand" preference removed (now always on) #228
- macOS: Added ability to hide dock icon and added statusbar #221
- macOS: Fix UI not updating correctly after removing provider #213
- macOS: Don't tell users about them pressing cancel, they know already
- macOS: Added popup for uninstall instructions older app #212
- macOS: Fixed resizing issue on connection view  #192
- iOS: Fix for app when no profiles configured. App should move to "add" screen.
- iOS: Fix crash on iOS 12 due to CryptoKit Linking. #238
- iOS/Mac: Fix double pushing of a screen on initial start of app when no instances are loaded yet.
- iOS/Mac: Update to TunnelKit 2.2.3
- macOS: Fix reconnect issue by preventing a new NESMVPNSession stuck in limbo after disconnect
- macOS: Ensure profiles are updated #260
- macOS: Display error messages correctly #260
- iOS/Mac: More detailed errors on invalid status codes. #263 #232
- macOS: Fix TunnelKit to get IPv6 working in macOS Mojave
- iOS: Prevent NETunnelProviderSession initialization after disconnect
- iOS/Mac: Update dependencies to latest versions. #273

## 2.1.1 (2020-01-06)

- macOS: Fix for UI not updating after approving #209

## 2.1.0 (2019-12-22)

- Built against SDK 13
- Dark mode
- Update dependencies
- Auto refresh log view
- Status images are now kept up to date with the actual VPN status
- Respect config `seq` value in configs.
- The value "seq" from discovery file is now respected. #147
- Ask for confirmation when disconnecting. #152
- Support Ed25519 X.509 certificates #107
- Bug fixing and clean up of old code.
- Codebase now supports both macOS and iOS.
- X.509 vpn cert/key now stored encrypted #188
- Workaround for macOS Mojave (10.14) now breaking IPv6 instead of IPv4 #191
- Institute access always uses own Auth server.


## 2.0.4  (2019-09-21)

- Update dependencies.
- Restrict encryption to known secure tlMinimum value is "128 bits" (level 3). More details about other effects of changing the TLS security level: [https://www.openssl.org/docs/manmaster/man3/SSL_CTX_set_security_level.html](https://www.openssl.org/docs/manmaster/man3/SSL_CTX_set_security_level.html).
- Version is now defined in AppVersion.xcconfig.
- Better handling of old discovery information.
- Fix for when switching to an other provided while connected. #86
- Enabled Data Protection.
- The app does not perform superflous refreshes of the profile list. This improves responsiveness. #88
- Fix for incorrectly displayed profile names. # 87
- Give an indication to the user what profile is configured on the system level, and show an in app connected status display.
- "Split tunnel" should now work. #75
- Attempt to delete the configuration if it is the current active configuration. #98
- Store OAuth.x509 data more securely. #91


## 2.0.3 (2019-04-04)

- Fix for data corruption when removing profile configs. #85
- Swift 5.
- Do not mask IP addresses in logging. #69

## 2.0.2 (2019-03-19)

- Fall back to instance base URI if no display name is defined.
- Fix crash on start-up if no "discovery" is defined.
- Remove everything related to 2FA/two factor.
- Show configured state on `Provider` list. Some clean-up.
- Retry certificate fetching if it is no longer valid. #50
- New UX/UI. #48
- Rename ChooseProviderTableViewController to ProviderTableViewController.
- Move storing of auth state and certificate to files, with data protection, excluded from backup. Fixes #49.
- Split project and product config.
- Revert back to using URL schemes for oAuth flow.
- Switch to use xcconfig based setting of project.
- Add localized message strings to system messages.
- Remove user messages, cleanup parsing of system messages.
- Improve naming of key name for Let's Connect!.
Localization.
- Update dependencies.
- No image for "Other" connections.
- Tweak empty connection table behavior to properly show and hide.
- Better error handling on server side error. Not everything is a local JSON mapping error.
- Add onDemand semantics.
- Add "Add configuration" button.
- Fix Core Data view context related warning.
- Add letsconnect redirect URL.
- Allow building with Let's Connect.
- Add configurations for each app family member. (EduVPN, AppForce 1 (Test) and Let's Connect)
- Only allow custom providers for letsconnect clients.
- Add migration and show better initial copy.
- Move TunnelProviderManager related code in a Coordinator.
- Make selective VPN display work.
- Show alert on missing auth flow.
- Remove "create_config" endpoint path.
- Take current configured profile into account when displaying.
- Show VPN connection view controller modally instead of pushed.
- Use correct label for out bytes.
- Notifications & improved status display.
- Rename federatedAuthorizationApi to distributedAuthorizationApi.
- Do not show errors due to user cancellation of auth flow.
- Add auth state check.
- Fix crash due to  on existant image literal.
- Display in/out byte counts.
- Add duration label updating.
- Remove reference to unused outlets.
- Start improving VPN connection screen.
- Update design of VPN selection screen. Also only allow adding a secure internet when there is not a already a secure internet profile present.

## 2.0.1 (2019-03-14)

- Retry refresh profile after a successful re-auth.
- Remove detection of OpenVPN.
- Make connecting with the app itself work.
- Update TunnelKit and adopt ovpn config parsing.
- Add Gemfile.
- Nasty hack to fix curve 7.
- Switch to TunnelKit. Migrate to Swift 4.2, update dependencies.
- Convert "print" statements to os_log.
- Allow log display.
- App now contains it's own tunnel extension. No need to have the OpenVPN connect app installed.

## 1.0.0 (unreleased)

- Distributed authorization/authentication support.
- Show activity information when loading a new instance.


## 0.113 (2018-06-01)

- Log in on EduVPN
- Handoff OpenVPN certificate to OpenVPN Connect app.
- Updated look and feel with big headers.
- Bugfix for iPad.
- Display progress with spinner and label informing user on app activity.
- Updated dependencies 


