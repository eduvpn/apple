The Let's Connect flavour of the app can be branded to work with a
predefined eduVPN server. In such an app, on first launch, the app will
present an _Add Predefined Server Screen_ that will enable the user to
add that predefined server. Other eduVPN servers can be added by URL
after that.

## Configuring

### config.json

 1. Copy the config.json from the template

    For macOS:

    ~~~
    $ cp Config/Mac/config-letsconnect_new_discovery.json Config/Mac/config.json
    ~~~

    For iOS:

    ~~~
    $ cp Config/iOS/config-letsconnect_new_discovery.json Config/iOS/config.json
    ~~~

 2. Modify the config.json

      - Edit `appName` if applicable

      - Edit `supportURL` if applicable

      - Add the `predefinedProvider` key, whose value is a dictionary
        with the following keys: 

          - `base_url`: The value should be the base URL for the eduVPN server

          - `display_name`: The value should be the name of the server, for display in the UI

            The value can be just a string (e.g. "ACME Corp."), or a dictionary
            mapping language codes to strings, like in the discovery json files
            (e.g. { "en": "ACME Corp.", "nl": "ACME" }).

        For example, the config.json could contain:

        ~~~
        "predefinedProvider": {
            "base_url": "https://nl.eduvpn.org/",
            "display_name": { "en": "ACME Corp.", "nl": "ACME" }
        }
        ~~~

      - Ensure that the value for `apiDiscoveryEnabled` is `false`. The
        _Add Predefined Server Screen_ is shown only when API discovery
        is not enabled.

### Developer xcconfig

Copy the developer xcconfig from the template and modify it as
applicable.

For macOS:

~~~
$ cp Config/Mac/Developer-macOS.xcconfig.letsconnect-template Config/Mac/Developer-macOS.xcconfig
$ vim Config/Mac/Developer-macOS.xcconfig # Edit as reqd.
~~~

For iOS:

~~~
$ cp Config/iOS/Developer.xcconfig.letsconnect-template Config/iOS/Developer.xcconfig
$ vim Config/iOS/Developer.xcconfig # Edit as reqd.
~~~

In iOS, we'd like to keep the `APP_NAME` without special characters, so if
your name has those, use a separate `APP_DISPLAY_NAME`, which can have
special characters.

### Images

The images are picked up from Assets files based on the `APP_NAME`
defined in the Developer xcconfig.

  - For macOS: `EduVPN/Resources/Mac/Assets-${APP_NAME}.xcassets/`
  - For iOS: `EduVPN/Resources/iOS/Assets-${APP_NAME}.xcassets/`

We're going to base our images on the Let's Connect flavour of the app,
so we should make a copy of that before building.

In macOS:

~~~
$ cp -r EduVPN/Resources/Mac/Assets-Let’s\ Connect\!.xcassets EduVPN/Resources/Mac/Assets-${APP_NAME}.xcassets/
$ ASSETS_DIR = EduVPN/Resources/Mac/Assets-${APP_NAME}.xcassets/
~~~

In iOS:

~~~
$ cp -r EduVPN/Resources/iOS/Assets-LetsConnect.xcassets EduVPN/Resources/iOS/Assets-${APP_NAME}.xcassets/
$ ASSETS_DIR = EduVPN/Resources/iOS/Assets-${APP_NAME}.xcassets/
~~~

#### Replacing images

Some of these images can be replaced to help in branding the app.

Under the `ASSETS_DIR`, there are imagesets. Each imageset contains
images for displaying in different sizes. To use a different image,
replace each image in the imageset with another image of the same size
with the same filename.

The following imagesets can be useful for branding:

  - **AppIcon.appiconset**: App icon
  - **TopBarLogo.imageset**: The image shown in the top navigation bar of
    the app. It's used in all screens in macOS, and in the main screen
    only in iOS.
  - **PredefinedProviderTopImage.imageset**: The image shown in the _Add
    Predefined Server Screen_ just above the predefined server's
    display name.

## Building

  - Open `EduVPN.xcworkspace` in Xcode.
  - For the iOS app, build the 'EduVPN-iOS' target. For the macOS app,
    build the 'EduVPN-macOS' target.
