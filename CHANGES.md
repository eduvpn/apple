# Changelog

## 2.0.4 

- Restrict encryption to known secure tls security ciphers.
- Version is now defined in AppVersion.xcconfig.
- Better handling of old discovery information.
- Fix for when switching to an other provided while connected. #86
- Enabled Data Protection.
- The app does not perform superflous refreshes of the proile list. This improves responsiveness. #88
- Fix for incorrectly displayed profile names. # 87
- Give an indication to the user what profile is configured on the system level, and show an in app connected status display.
- Lots and lots of updates to third party dependencies.
- "Split tunnel" should now work. #75

## 2.0.3

- Fix for data corruption when removing profile configs. #85
- Swift 5.
- Do not mask IP addresses in logging. #69

## 2.0.2

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

## 2.0.1

- Retry refresh profile after a successful re-auth.
- Remove detection of OpenVPN.
- Make connecting with the app itself work.
- Update TunnelKit and adopt ovpn config parsing.
- Add Gemfile.
- Nasty hack to fix curve 7.
- Switch to TunnelKit. Migrate to Swift 4.2, update dependencies.
- Convert "print" statements to os_log.
- Allow log display.

## 2.0.0

- App now contains it's own tunnel extension. No need to have the OpenVPN connect app installed.

## 1.0.0

- Distributed authorization/authentication support.
- Show activity information when loading a new instance.


## 0.113 (?)

- Log in on EduVPN
- Handoff OpenVPN certificate to OpenVPN Connect app.
- Updated look and feel with big headers.
- Bugfix for iPad.
- Display progress with spinner and label informing user on app activity.
- Updated dependencies 


