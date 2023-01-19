#!/usr/bin/env bash

# This script is to help create the macOS installation package for distribtuing
# the macOS app outside of the Mac App Store, using Developer ID Distribution
#
# For eduVPN, run:
#   Scripts/create_eduvpn_installer_macos.sh -n eduvpn -u <apple-id> -p <password>
#
# For Let's Connect, run:
#   Scripts/create_eduvpn_installer_macos.sh -n letsconnect -u <apple-id> -p <password>
#
# If you've enabled 2FA for your Apple ID, you will need to get an app-specific password
# from appleid.apple.com and pass that as the argument for the -p switch.

APP_VERSION="3.0.6"
MIN_MACOS_VERSION="10.15.0"

EDUVPN_APP_NAME="eduVPN"
EDUVPN_APP_ID="org.eduvpn.app"
EDUVPN_DEVELOPMENT_TEAM="ZYJ4TZX4UU"
EDUVPN_INSTALLER_CERTIFICATE_CN="Developer ID Installer: SURF B.V. (ZYJ4TZX4UU)"

LETSCONNECT_APP_NAME="Let’s Connect!"
LETSCONNECT_APP_ID="com.commonscaretakers.letsconnect.mac"
LETSCONNECT_DEVELOPMENT_TEAM="D9T87NF4Q7"
LETSCONNECT_INSTALLER_CERTIFICATE_CN="Developer ID Installer: Commons Caretakers b.v. (D9T87NF4Q7)"

usage() { echo "Usage: $0 -n <eduvpn|letsconnect> -u <apple-id> -p <apple-id-password>" 1>&2; exit 1; }

while getopts ":n:u:p:" o; do
    case "${o}" in
        n)
            n=${OPTARG}
            ((n == "eduvpn" || n == "letsconnect")) || usage
            ;;
        u)
            u=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${n}" ] || [ -z "${u}" ] || [ -z "${p}" ]; then
    usage
fi

case "${n}" in
    eduvpn)
        APP_NAME=${EDUVPN_APP_NAME}
        APP_ID=${EDUVPN_APP_ID}
        DEVELOPMENT_TEAM=${EDUVPN_DEVELOPMENT_TEAM}
	CERTIFICATE_CN=${EDUVPN_INSTALLER_CERTIFICATE_CN}
	;;
    letsconnect)
        APP_NAME=${LETSCONNECT_APP_NAME}
        APP_ID=${LETSCONNECT_APP_ID}
        DEVELOPMENT_TEAM=${LETSCONNECT_DEVELOPMENT_TEAM}
	CERTIFICATE_CN=${LETSCONNECT_INSTALLER_CERTIFICATE_CN}
	;;
esac

echo "Creating installation package with:"
echo "  APP_NAME = ${APP_NAME}"
echo "  APP_ID = ${APP_ID}"
echo "  DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}"
echo "  CERTIFICATE_CN=${CERTIFICATE_CN}"

echo ""
echo "Checking app..."
if [ -f "${APP_NAME}.app" ]; then
    spctl -vvv --assess -t exec "${APP_NAME}.app" 2>&1 | tee /tmp/spctl_app.log
    if grep -q accepted /tmp/spctl_app.log; then
	echo "App \"${APP_NAME}.app\" appears to be notarized."
    else
        echo "Error: App \"${APP_NAME}.app\" is not notarized. Not creating installer." 1>&2; exit 1;
    fi
    rm -rf /tmp/spctl_app.log
else
    echo "Error: App \"${APP_NAME}.app\" not found. Not creating installer." 1>&2; exit 1;
fi

echo ""
echo "Creating installer package..."
pkgbuild --root "\"${APP_NAME}.app\"" --identifier ${APP_ID} --version ${APP_VERSION} --install-location "\"/Applications/${APP_NAME}.app\"" --min-os-version ${MIN_MACOS_VERSION} --sign "\"${CERTIFICATE_CN}\"" ./${n}_${APP_VERSION}.pkg

echo ""
echo "Notarizing installer package..."
xcrun notarytool submit ./${n}_${APP_VERSION}.pkg --apple-id "${u}" --password "${p}" --team-id ${DEVELOPMENT_TEAM} --wait

echo ""
echo "Adding notarization information to package..."
xcrun stapler staple ./${n}_${APP_VERSION}.pkg

echo "Checking installer package..."
if [ -f "./${n}_${APP_VERSION}.pkg" ]; then
    spctl -vvv --assess -t install "./${n}_${APP_VERSION}.pkg" 2>&1 | tee /tmp/spctl_installer.log
    if grep -q accepted /tmp/spctl_installer.log; then
	echo "Looks good."
    else
        echo "Error: \"./${n}_${APP_VERSION}.pkg\" is not notarized." 1>&2; exit 1;
    fi
    rm -rf /tmp/spctl_installer.log
else
    echo "Error: \"./${n}_${APP_VERSION}.pkg\" is not found." 1>&2; exit 1;
fi

echo ""
echo "Notarized installation package is at: ./${n}_${APP_VERSION}.pkg"

