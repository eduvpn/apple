# Developer ID Distribution for Mac

The macOS app can be distributed outside of the App Store using Developer ID
distribution.

These targets are used for the Developer ID version of the app:

  - **EduVPN-macOS-DeveloperID**

    The container app. On launch, installs the System Extension, if required.

  - **TunnelExtension-macOS-DeveloperID**

    The tunnel extension, bundled as a System Extension.

  - **LoginItemHelper-macOS-DeveloperID**

    The helper app that launches the app on login.

## Pre-requisites

SwiftLint and Go need to be installed. The build setup looks for these in the paths that HomeBrew installs into.

To install, run:
~~~
brew install swiftlint go
~~~

Go version 1.16 is required.

## Building

### eduVPN

To build the app, run:
```
$ cp Config/Mac/config-eduvpn_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/privacy_statement-eduvpn.json Config/Mac/privacy_statement.json
$ cp Config/Mac/Developer-macOS.xcconfig.eduvpn-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-macOS-DeveloperID' target.

### Let's Connect

To build the app, run:
```
$ cp Config/Mac/config-letsconnect_new_discovery.json Config/Mac/config.json
$ cp Config/Mac/privacy_statement-letsconnect.json Config/Mac/privacy_statement.json
$ cp Config/Mac/Developer-macOS.xcconfig.letsconnect-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
```

Then, open `EduVPN.xcworkspace` in Xcode and build the 'EduVPN-macOS-DeveloperID' target.

## Distribution

This section describes how to create the installation package file (.pkg) that
can be distributed to end users.

### One-time Set-up

Before starting on creating a Developer ID release, we need to create some
Certificates, Identifiers, and Provisioning Profiles in the [Apple Developer
Account website][].

[Apple Developer Account website]: https://developer.apple.com/account/

#### Certificates

We need to create the certificates we will use to sign the executables and
installers that we want to distribute.

 1. Developer ID Application Certificate

      - Click on _Certificates_, then on _+_ to add a certificate. Choose _Developer ID Application_.
      - Choose _G2 Sub-CA_ profile
      - Create a Certificate Signing Request on your Mac as specified in the page and upload it
      - _Download_ the created certificate
      - Open "Keychain Access.app", choose the default keychain, and drag the downloaded certificate file to install it in the default keychain
      - In the Keychain Access app window, double-click on the installed certificate to view it -- note down the expiry date somewhere

 2. Developer ID Installer Certificate

      - Click on _Certificates_, then on _+_ to add a certificate. Choose _Developer ID Installer_.
      - Choose _G2 Sub-CA_ profile
      - Create a Certificate Signing Request on your Mac as specified in the page and upload it
      - _Download_ the certificate
      - Open "Keychain Access.app", choose the default keychain, and drag the downloaded certificate file to install it
      - In the Keychain Access app, double-click on the installed certificate to view it -- note down expiry date somewhere


Developer ID Application Certificates and Developer ID Installer Certificates
are valid for 5 years from when they were created.

The application should be signed when the Developer ID Application
Certificate is valid -- the installed application will continue to run after the
Developer ID Application certificate expires.

The installer will stop working after the Developer ID Installer Certificate
expires.

#### Identifiers

We need to create explicit bundle ids for the bundles we need to distribute,
and declare what capabilities they should be allowed to have.

 1. App

      - Click on _Identifiers_, choose _App IDs_, click on _Continue_
      - Select _App_ type, click on _Continue_
      - Enter a _Bundle ID_, say "com.example.app"
      - Ensure _Explicit_ is checked next to the Bundle ID
      - Enter a _Description_ (you can use spaces instead of special characters)
      - Under _Capabilities_, choose _Network Extensions_ and _System Extension_
      - Click on _Continue_, then _Register_

 2. Tunnel Extension

      - Click on _Identifiers_, choose _App IDs_, click on _Continue_
      - Select _App_ type, click on _Continue_
      - Enter _Bundle ID_ with a "TunnelExtension" suffix, say "com.example.app.TunnelExtension"
      - Ensure _Explicit_ is checked next to the Bundle ID
      - Enter a _Description_ (you can use spaces instead of special characters)
      - Under _Capabilities_, choose _Network Extensions_
      - Click on _Continue_, then _Register_

 3. Login Item Helper

      - Click on _Identifiers_, choose _App IDs_, click on _Continue_
      - Select _App_ type, click on _Continue_
      - Enter _Bundle ID_ with a "LoginItemHelper" suffix, say "com.example.app.LoginItemHelper"
      - Ensure _Explicit_ is checked next to the Bundle ID
      - Enter a _Description_ (you can use spaces instead of special characters)
      - Don't tick anything under _Capabilities_
      - Click on _Continue_, then _Register_

#### Profiles

For each bundle id we created, we need to create a provisioning profile that
ties the bundle id to a Developer ID Application Certificate.

 1. App

      - Click on _Profiles_, then on _+_ to add a profile, choose _Developer ID_ under _Distribution_, then click on _Continue_
      - Ensure Profile Type is _Mac_, choose the _App ID_ created earlier (you can type to search), and click on _Continue_
      - Choose the _Developer ID Application_ certificate created earlier (you will have to choose by expiry date), click on _Continue_
      - Enter a _Provisioning Profile Name_, say "eduVPN Developer ID App 01 Jan 2023"
      - Click on _Generate_, then on _Download_. Save the file somewhere (say "eduVPN_dev_id_app.provisionprofile").

 2. Tunnel Extension

      - Click on _Profiles_, then on _+_ to add a profile, choose _Developer ID_ under _Distribution_, then click on _Continue_
      - Ensure Profile Type is _Mac_, choose the _Bundle ID_ with a "TunnelExtension" suffix created earlier (you can type to search), and click on _Continue_
      - Choose the _Developer ID Application_ certificate created earlier (you will have to choose by expiry date), click on _Continue_
      - Enter a _Provisioning Profile Name_, say "eduVPN Developer ID Tunnel Extension 01 Jan 2023"
      - Click on _Generate_, then on _Download_. Save the file somewhere (say "eduVPN_dev_id_tunnelextension.provisionprofile").

 3. Tunnel Extension

      - Click on _Profiles_, then on _+_ to add a profile, choose _Developer ID_ under _Distribution_, then click on _Continue_
      - Ensure Profile Type is _Mac_, choose the _Bundle ID_ with a "LoginItemHelper" suffix created earlier (you can type to search), and click on _Continue_
      - Choose the _Developer ID Application_ certificate created earlier (you will have to choose by expiry date), click on _Continue_
      - Enter a _Provisioning Profile Name_, say "eduVPN Developer ID Login Item Helper 01 Jan 2023"
      - Click on _Generate_, then on _Download_. Save the file somewhere (say "eduVPN_dev_id_loginitemhelper.provisionprofile").

The provisioning profiles are valid for 18 years from the time they are
generated. The installed app will stop working when the provisioning profile
expires.

### Making a Release

 1. In Xcode, open the Projects and Targets pane

      - Open the project in Xcode
      - In the Project Navigator (keyboard shortcut: Cmd+1), select "EduVPN" at the top left

 2. Setup app's provisioing profile

      - Select the _EduVPN-macOS-DeveloperID_ target
      - Select the _Signing & Capabilities_ tab, and under that, the _Release_ tab
      - Ensure _Automatically manage signing_ is not checked
      - Under _macOS_, choose a _Provisioning Profile_. You can use _Import Profile..._ to import the downloaded profile (say "eduVPN_dev_id_app.provisionprofile"), or choose an already imported profile.

 3. Setup tunnel extension's provisioning profile

      - Select the _TunnelExtension-macOS-DeveloperID_ target
      - Select the _Signing & Capabilities_ tab, and under that, the _Release_ tab
      - Ensure _Automatically manage signing_ is not checked
      - Under _macOS_, choose a _Provisioning Profile_. You can use _Import Profile..._ to import the downloaded profile (say "eduVPN_dev_id_tunnelextension.provisionprofile"), or choose an already imported profile.

 4. Setup login item helper's provisioning profile

      - Select the _LoginItemHelper-macOS-DeveloperID_ target
      - Select the _Signing & Capabilities_ tab, and under that, the _Release_ tab
      - Ensure _Automatically manage signing_ is not checked
      - Under _macOS_, choose a _Provisioning Profile_. You can use _Import Profile..._ to import the downloaded profile (say "eduVPN_dev_id_loginitemhelper.provisionprofile"), or choose an already imported profile.

 5. Create the archive

      - At the top of the window, select _EduVPN-macOS-DeveloperID_ > _My Mac_
      - In the Xcode menu, choose _Product_ > _Clean Build Folder_
      - In the Xcode menu, choose _Product_ > _Archive_
      - Once the archive is created, Xcode will open its Organizer window, with the created archive selected

 6. Create the notarized app bundle

      - Ensure that the created archive is selected in the Organizer window
      - Click on _Distribute App_
         - Select _Developer ID_, click _Next_
         - Select _Upload_, click _Next_
         - Set the _Distribution certificate_ as the _Developer ID Application Certificate_ we created
         - Choose the appropriate provisioning profiles for the app, tunnel extension, and login item helper. You will see the already imported profiles in the dropdown menu. Click _Next_.
         - Click _Upload_.  Wait for Apple to notarize it (it generally takes less than 5 mins, but can take a maximum of 15 mins).
      - Export the notarized app bundle
         - If the "Distribute App" modal window (that you used to upload the app for notarization) is still open, click on _Export_ to export the app. Else, select the archive in the Organizer window (status should be "Ready to Distribute"), and click on _Export Notarized App_ in the right-side inspector pane.
         - Save the app bundle somewhere (say "dev_id_release/eduVPN.app")

 7. Create the installer package

      - Edit the installer creation script

        Ensure that the variables at the top are all correct.

        ~~~
        vim Scripts/create_eduvpn_installer_macos.sh
        ~~~

      - Run the installer creation script

        `cd` to the directory containing the notarized app file.

        ~~
        cd dev_id_release
        ~~

	&lt;username&gt; should be the Apple ID that controls the developer
        account for this app.

	&lt;password&gt; should be the password for that Apple ID. If 2FA is
        enabled for this Apple ID, you will need to generate an app-specific password
        at [appleid.apple.com](https://appleid.apple.com) (Sign In > App-specific
        Passwords) and specify that password.

          - For eduVPN:

            ~~~
            bash Scripts/create_eduvpn_installer_macos.sh -n eduvpn -u <username> -p <password>
            ~~~

          - For Let's Connect:

            ~~~
            bash Scripts/create_eduvpn_installer_macos.sh -n letsconnect -u <username> -p <password>
            ~~~

        The notarized installer package will be created in the same directory.

## Development

To work on the Developer ID / System Extension installation part of the app in
Xcode conveniently (for e.g. to launch the app from Xcode), we should:

  - Disable System Integrity Protection (SIP)

    In macOS Recovery mode, launch Terminal.app, and run `csrutil disable`.

    If possible, you can install macOS on a separate partition or external disk
    and disable SIP on that macOS installation, so that your primary macOS
    installation remains SIP-protected.

  - Enable System Extension developer-mode

    Run `systemextensionsctl developer on`

The `systemextensionsctl` command can be useful during development:

  - `systemextensionsctl list` shows the installation status of the System Extension
  - `systemextensionsctl reset` uninstalls all System Extensions
